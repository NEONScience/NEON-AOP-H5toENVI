; docformat = 'rst'
;+
; :Description:
;     AOPH5toENVI is an ENVI extension designed read in NEON AOP H5 data products.
;
; :Requires:
;     ENVI 5.2 / IDL 8.4
;
; :Author: Josh Elliott jelliott@neoninc.org
;
; :History:
;   Created Dec 24, 2014 10:17:18 AM
;
; $Rev: 7782 $
; $Date: 2016-01-19 15:37:55 -0700 (Tue, 19 Jan 2016) $
;-


;-------------------------------------------------------------------------------
;+
; :Description:
;    Add the extension to the toolbox. Called automatically on ENVI startup.
;-
pro AOPH5toENVI_extensions_init
  compile_opt IDL2

  ; Get ENVI session
  e = ENVI(/CURRENT)

  ; Add the extension to a subfolder
  e.AddExtension, 'NEON AOP H5 Reader', 'AOPH5toENVI', PATH='NEON'
  _addNEONOpenToFileMenu
  id = Timer.Set(3.0, '_setNEONBitmap') ;)
end

;-------------------------------------------------------------------------------
;+
; :Description:
;    Just for kicks, place this under "open-as" as well.
;-
pro _addNEONOpenToFileMenu
  compile_opt idl2, hidden
  e = envi(/CURRENT)
  e.AddCustomReader, 'NEON AOP H5 Reader', 'AOPH5toENVI', PATH='NEON'
end

;-------------------------------------------------------------------------------
;+
; :Description:
;    Set the NEON tree item to the NEON logo.
;-
pro _setNEONBitmap, id, userData
  compile_opt idl2, hidden
  
  ; First, a quick little Breadth-First-Search to get the tree widget element
  e = envi(/CURRENT)
  wid = _neonTreeFinder(e.WIDGET_ID)
  if (~widget_info(wid, /VALID_ID)) then begin
    return
  endif
  
  ; Read the bitmap
  imgFile = e.ROOT_DIR + 'extensions' + path_sep() + 'smallneonlogo.png'
  if (~file_test(imgFile)) then begin
    return
  endif
  img = read_png(e.ROOT_DIR + 'extensions' + path_sep() + 'smallneonlogo.png')
  img = congrid(img, 3,16,16)
  r = bytarr((img.dim)[1:2])
  g = r
  b = r
  r[*,*] = img[0,*,*]
  g[*,*] = img[1,*,*]
  b[*,*] = img[2,*,*]
  img = bytarr(shift(img.dim, -1))
  img[*,*,0] = r
  img[*,*,1] = g
  img[*,*,2] = b
  
  ; Set the tree widget icon
  widget_control, wid, SET_TREE_BITMAP=img
  children = widget_info(wid, /ALL_CHILDREN)
  foreach child, children do begin
    if (widget_info(child, /VALID_ID) && (widget_info(child, /type) eq 11)) then begin
      widget_control, child, SET_TREE_BITMAP=img
    endif
  endforeach
end

;-------------------------------------------------------------------------------
;+
; :Description:
;    A quick little Breadth-First-Search to get the tree widget element
;
; :Params:
;    v  [in, req, widgetID] : Widget ID, the root of the widget hierarchy to search.
;-
function _neonTreeFinder, v
  compile_opt idl2, hidden
  queue = list()
  Vset = list()
  Vset.add, v
  queue.add, v
  while (~queue.IsEmpty()) do begin
    t = queue.Remove(0)

    if (widget_info(t, /VALID_ID)) then begin
      if (widget_info(t, /type) eq 11) then begin
        widget_control, t, GET_UVALUE=uvalue, GET_VALUE=value
        if (value eq "NEON") then begin
          return, t
        endif
      end

      children = widget_info(t, /ALL_CHILDREN)
      foreach child, children do begin
        if (~widget_info(child, /VALID_ID)) then begin
          continue
        endif
        if (Vset.Count(child) eq 0) then begin
          Vset.add, child
          queue.add, child
        endif
      endforeach
    endif

  endwhile
  return, 0
end

pro _aopDatasetChooser_event, ev
  compile_opt idl2
  
  wBase = ev.TOP
  widget_control, wBase, GET_UVALUE=h
  datasets = h["datasets"]
  wID = ev.ID
  uName = widget_info(wID, /UNAME)
  
  case (uName) of
    "OK": begin
      
      ; Get the dataset names that are selected
      output = List()
      foreach dataset, datasets do begin
        wCheckBox = widget_info(wBase, FIND_BY_UNAME=dataset)
        if (widget_info(wCheckBox, /VALID_ID)) then begin
          isChecked = widget_info(wCheckBox, /BUTTON_SET)
          if (isChecked) then begin
            output.add, dataset
          endif
        endif
      endforeach
      
      ; Set the datasets to output
      h["datasets"] = output
      
      ; Close the widget
      widget_control, wBase, /DESTROY
    end
    "Cancel": begin
      widget_control, wBase, /DESTROY
    end
    else: begin
      ;no op
    end
  endcase

end

function _aopDatasetChooser, h5
  compile_opt idl2
  
  e = envi(/CURRENT)
  if (~obj_valid(e)) then begin
    return, !null
  endif
  
  wENVI = e.WIDGET_ID
  
  wBase = widget_base(/MODAL, GROUP_LEADER=wENVI, $
    TITLE="Select the desired data set(s): ", $
    /COLUMN)
  
  ; Get a list of the raster datasets in the file
  datasets = list()
  keys = h5.keys()
  foreach key, keys do begin
    if (isa(h5[key], 'hash')) then begin
      if ((h5[key]).haskey('_NDIMENSIONS')) then begin
        ndims = h5[key, '_NDIMENSIONS']
        dims = h5[key, '_DIMENSIONS']
        if ndims eq 3 || (ndims eq 2 && (dims[0] gt 1 && dims[1] gt 1)) then begin
          datasets.add, key
        endif
      endif
    endif
  endforeach
  
  wNEONLogo = widget_draw(wBase, XSIZE=415, ysize=120, RETAIN=2)
  wButtonBase = widget_base(wBase, /NONEXCLUSIVE)
  foreach dataset, datasets do begin
    wButton = widget_button(wButtonBase, VALUE=h5[dataset, '_NAME'], UNAME=dataset)
  endforeach
  wSelectButton = widget_button(wBase, VALUE="OK", UNAME="OK")
  wCancel = widget_button(wBase, VALUE="Cancel", UNAME="Cancel")
  
  h = hash()
  h["datasets"] = datasets
  
  widget_control, wBase, SET_UVALUE=h
  widget_control, wBase, /REALIZE
  
  ; Read the bitmap
  imgFile = e.ROOT_DIR + 'extensions' + path_sep() + 'NEON-Logo.png'
  widget_control, wNEONLogo, get_value=drawid
  wset, drawid
  if (file_test(imgFile)) then begin
    img = read_png(imgFile)    
    tv, img, true=1
  endif else begin
    xyouts, 0.1, 0.1, 'NEON Inc.', /normal
  endelse
  
  XMANAGER, '_aopDatasetChooser', wBase
  
  return, h["datasets"]
end

function OpenAOPH5, filename, DATASET_NAME=datasetName
  compile_opt idl2
  AOPH5toENVI, FILENAMES=filename, DATASET_NAME=datasetName, _getrasters=raster, /headless
  return, raster[0]
end

;-------------------------------------------------------------------------------
;+
; :Description:
;    ENVI Extension code. Called when the toolbox item is chosen.
;-
pro AOPH5toENVI, none, FILENAMES=filenames, DATASET_NAME=datasetName, _getrasters=rasters, HEADLESS=headless
  compile_opt IDL2
  
  ; Version Check
  if (!version.RELEASE lt 8.4) then begin
    !null = dialog_message("This ENVI extension requires ENVI 5.2 or greater.", /ERROR)
    return
  endif

  ; General error handler
;  CATCH, err
;  if (err ne 0) then begin
;    CATCH, /CANCEL
;    if OBJ_VALID(e) then $
;      e.ReportError, 'ERROR: ' + !error_state.msg
;    MESSAGE, /RESET
;    return
;  endif

  ; Get ENVI session
  e = ENVI(/CURRENT)

  ; Get the files
  if (~isa(filenames)) then begin
    files = dialog_pickfile(FILTER='*.h5', /MULTIPLE_FILES)
  endif else begin
    files = filenames[*]
  endelse
  
  if (~isa(datasetName)) then begin
    ; Let the user select which datasets to open.
    file = files[0]
    if (file.StrLen() gt 0) then begin
      h5 = hash(h5_parse(file), /EXTRACT)
    endif else begin
      return
    endelse
    datasets = _aopDatasetChooser(h5)
  endif else begin
    datasets = [datasetname]
  endelse
  
  foreach file, files do begin
    if (file.StrLen() lt 1) then begin
      continue
    endif
    
    ; Parse the HDF5 file structure into an easy to read HASH()
    h5 = hash(h5_parse(file), /EXTRACT)
    
    rasters = []
    foreach dataset, datasets do begin
      if (~h5.haskey(dataset)) then begin
        continue
      endif
           
      ; Create the georeferencing metadata
      spatialRef = AOPh5MetadataFactory.CreateSpatialRef(h5)

      ; Create metadata object
      metadata = AOPh5MetadataFactory.CreateMetadata(h5, dataset)

      ; Open the raster
      raster = e.OpenRaster(file, $
        DATASET_NAME= '/' + h5[dataset, '_NAME'], $
        SPATIALREF_OVERRIDE=spatialRef, $
        METADATA_OVERRIDE=metadata)
      rasters = [rasters, raster]
      
      ; Display the data
      if (~keyword_set(HEADLESS)) then begin
        view = e.GetView()
        layer = view.CreateLayer(raster)
      endif
    endforeach
  endforeach
end
