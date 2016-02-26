; docformat = 'rst'
;+
; :Description:
;     AOPh5MetadataFactory is a class with static methods designed
;     to create and return metadataobjects such as an ENVIRasterMetaData or an
;     ENVIStandardRasterSpatialRef.  These objects can then
;     be passed to the ENVI Raster constructor.
;     
; :Requires:
;     ENVI 5.2 / IDL 8.4
;
; :Author: Josh Elliott jelliott@neoninc.org
;
; :History:
;   Created Jan 22, 2015 3:32:26 PM
;   
; $Rev: 7397 $
; $Date: 2015-10-15 09:45:22 -0600 (Thu, 15 Oct 2015) $
;-

;-------------------------------------------------------------------------------
;+
; :Description:
;    Constructor
;
; :Keywords:
;    _EXTRA
;-
function AOPh5MetadataFactory::Init, _EXTRA=extra
  compile_opt idl2  
  if (isa(extra)) then begin
    self.AOPh5MetadataFactory::SetProperty, _EXTRA=extra
  endif
  return, 1
end

;-------------------------------------------------------------------------------
;+
; :Description:
;     Destructor
;-
pro AOPh5MetadataFactory::Cleanup
  compile_opt idl2
  
end

;-------------------------------------------------------------------------------
;+
; :Description:
;     Accessor
;-
pro AOPh5MetadataFactory::GetProperty, _REF_EXTRA=extra
  compile_opt idl2

end

;-------------------------------------------------------------------------------
;+
; :Description:
;     Mutator
;-
pro AOPh5MetadataFactory::SetProperty, _EXTRA=extra
  compile_opt idl2

end

;-------------------------------------------------------------------------------
;+
; :Description:
;    Static method to return an ENVIRasterMetadata object for a particular dataset
;    contained within an h5 file.
;    
; :Params:
;    h5           [in, req, Hash] : h5 file structure, Hash() object.
;    dataSetName  [in, req, IDL_String] : Data set name.
;    
; :Returns:
;    ENVIRasterMetadata
;-
function AOPh5MetadataFactory::CreateMetadata, h5, dataSetName
  compile_opt static, idl2
  
  metadata = !null
  
  dataSetNameUpper = dataSetName.toUpper()
  
  case (dataSetNameUpper) of
    'REFLECTANCE': metadata = AOPh5MetadataFactory._Reflectance(h5, dataSetNameUpper)
    'DARK_DENSE_VEGETATION_CLASSIFICATION' : metadata = AOPh5MetadataFactory._Class(h5, dataSetNameUpper)
    'HAZE_CLOUD_WATER_MAP' : metadata = AOPh5MetadataFactory._Class(h5, dataSetNameUpper)
    else: metadata = AOPh5MetadataFactory._Raster(h5, dataSetNameUpper)
  endcase
  
  return, metadata
end

;-------------------------------------------------------------------------------
;+
; :Description:
;    Static method to return an ENVIStandardRasterSpatialRef for the h5 datasets.
;
; :Params:
;    h5           [in, req, Hash] : h5 file structure, Hash() object.
;-
function AOPh5MetadataFactory::CreateSpatialRef, h5
  compile_opt static, idl2
    
  ; Get coordinate system information
  mapStuff = strsplit((h5['MAP_INFO','_DATA'])[0], ',', /EXTRACT)
  coordSysString = (h5['COORDINATE_SYSTEM_STRING','_DATA'])[0]
  
  ; Get the pixel size
  ps = double(mapStuff[5:6])
  
  ; Get the pixel tie point
  tp = double(mapStuff[1:2])
  
  ; Get the map tie point
  tm = double(mapStuff[3:4])
  
  ; Get the rotation, if any
  if (mapStuff[-1].Contains('rotation')) then begin
    rotation = double((strsplit(mapStuff[-1],'=', /EXTRACT))[-1])
  endif else begin
    rotation = !null
  endelse
  
  ; Create the spatial ref object
  spatialRef = ENVIStandardRasterSpatialRef( $
    COORD_SYS_STR=coordSysString, $
    PIXEL_SIZE=ps, $
    TIE_POINT_MAP=tm, $
    TIE_POINT_PIXEL=[0,0], $
    ROTATION=rotation)
  
  return, spatialRef
end

;+
; :Description:
;
;-
function AOPh5MetadataFactory::CreateTime, h5
  compile_opt idl2

  ; TODO: We should be adding the Acquisition time to the h5 file metadata.
  return, 1
end


;-------------------------------------------------------------------------------
;+
; :Description:
;    Reflectance
;
; :Params:
;    h5           [in, req, Hash] : h5 file structure, Hash() object.
;    dataSetName  [in, req, IDL_String] : Data set name.
;
; :Returns:
;    ENVIRasterMetadata
;-
function AOPh5MetadataFactory::_Reflectance, h5, dataSetName
  compile_opt static, idl2

  metadata = envirastermetadata()

  ; Wavelength / Spectral Radiance Bands
  metadata.AddItem, 'wavelength', h5_getdata(h5['_FILE'], '/' + h5['WAVELENGTH','_NAME'])
  metadata.AddItem, 'wavelength units', h5['WAVELENGTH','UNIT','_DATA']

  ; FWHM
  metadata.AddItem, 'fwhm', h5_getdata(h5['_FILE'], '/' + h5['FWHM','_NAME'])
  
  AOPh5MetadataFactory._AddCommonRasterMetadata, h5, dataSetName, metadata

  return, metadata
end

;+
; :Description:
;
;-
function AOPh5MetadataFactory::_Class, h5, dataSetName
  compile_opt static, idl2

  metadata = envirastermetadata()
  AOPh5MetadataFactory._AddCommonClassificationMetadata, h5, dataSetName, metadata
  return, metadata
end

;+
; :Description:
;
;-
function AOPh5MetadataFactory::_Raster, h5, dataSetName
  compile_opt static, idl2

  metadata = envirastermetadata()
  AOPh5MetadataFactory._AddCommonRasterMetadata, h5, dataSetName, metadata
  return, metadata

  return, 1
end

;+
; :Description:
;
;-
pro AOPh5MetadataFactory::_AddCommonRasterMetadata, h5, dataSetName, metadata
  compile_opt static, idl2

  ; Scale factor
  if ((h5[dataSetName]).haskey('SCALE_FACTOR')) then begin
    metadata.AddItem, 'reflectance scale factor', h5[dataSetName,'SCALE_FACTOR','_DATA']
  endif
    
  ; Description
  if ((h5[dataSetName]).haskey('DESCRIPTION')) then begin
    metadata.AddItem, 'description', h5[dataSetName,'DESCRIPTION','_DATA']
  endif
  
  ; Sun angles
  if (h5.haskey('SOLAR_AZIMUTH_ANGLE')) then begin
    metadata.AddItem, 'sun azimuth', (h5['SOLAR_AZIMUTH_ANGLE','_DATA'])[0]
  endif
  if (h5.haskey('SOLAR_ZENITH_ANGLE')) then begin
    metadata.AddItem, 'sun elevation', 90.0 - (h5['SOLAR_ZENITH_ANGLE','_DATA'])[0]
  endif
  
  ; data-ignore-value
  if ((h5[dataSetName]).haskey('DATA_IGNORE_VALUE')) then begin
    metadata.AddItem, 'data ignore value', fix(h5[dataSetName, 'DATA_IGNORE_VALUE', '_DATA'])
  endif
  
  ; Units, if specified
  if ((h5[dataSetName]).haskey('UNIT')) then begin
    metadata.AddItem, 'data units', h5[dataSetName, 'UNIT', '_DATA']
  endif
end

;+
; :Description:
;
;-
pro AOPh5MetadataFactory::_AddCommonClassificationMetadata, h5, dataSetName, metadata
  compile_opt static, idl2
  
  ; Add class names and look-up-table (LUT)
  classNames = (h5[dataSetName, 'CLASS_NAMES', '_DATA']).split(',')
  classLookup = byte(fix((h5[dataSetName, 'CLASS_LOOKUP', '_DATA']).split(',')))
  classLookup = reform(classLookup, 3, classLookup.length/3)
  metadata.AddItem, 'classes', classNames.length
  metadata.AddItem, 'class names', classNames
  metadata.AddItem, 'class lookup', classLookup
  
  ; Add band name(s)
  bandNames = [(h5[dataSetName, 'BAND_NAMES', '_DATA']).replace('/', '_')]
  metadata.AddItem, 'band names', bandNames
end


;-------------------------------------------------------------------------------
;+
; :Description:
;     Class data definition procedure
;-
pro AOPh5MetadataFactory__define
  compile_opt idl2

  !NULL = {AOPh5MetadataFactory,  $
    inherits IDL_Object           $
  }
end
