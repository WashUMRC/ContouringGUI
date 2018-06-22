function [out,outHeader] = scancoParameterCalculatorCancellousCallus(bw,bw2,img,info)

%bw is the trabecular structures
%bw2 is the whole metaphyseal compartment being analyzed
%img is the original DICOM images
%info is one of the info structs for metadata

% info.SliceThickness = info.SliceThickness / 1000;

%Find bone volume
BV = length(find(bw)) * info.SliceThickness^3;
%find total volume
TV = length(find(bw2)) * info.SliceThickness^3;
%find BV/TV
BVTV = BV/TV;

bwFilled = bw2;
clear bw2;

%find the ultimate erosion to identify the local maxima in the binary array
bwUlt = bwulterode(bw);
%identify the background of the binary array
bwBackground = ~bw;
bwBackground(~bwFilled) = 0;
D1 = bwdist(bw);%does what I want for thickness of spacing
D2 = bwdist(bwBackground);%does what I want for thickness of structures
D2(~bwFilled) = 0;
D1(~bwFilled) = 0;

%do foreground structure
rads = D2(find(D2));%(find(bwUlt));%find the radii of the spheres at the local maxima
[r c v] = ind2sub(size(bwUlt),find(bwUlt));
xyzUlt = [r c v];%find xyz coords of the local maxima
xyzUlt = xyzUlt .* info.SliceThickness;%convert to physical units
diams = 2 * rads .* info.SliceThickness;%convert to diameters and in physical units

TbTh = mean(diams);%mean structure thickness
TbThSTD = std(diams);%standard deviation of structure thicknesses

%do background structure
bwNotFilled = bwFilled;
bwNotFilled(bw) = 0;
bwUlt = bwulterode(bwNotFilled);
rads = D1(find(bwUlt));%find the radii of the spheres at the local maxima
[r c v] = ind2sub(size(bwUlt),find(bwUlt));
% xyzUlt = [r c v];%find xyz coords of the local maxima
% xyzUlt = xyzUlt .* info.SliceThickness;%convert to physical units
diams = 2 * rads .* info.SliceThickness;%convert to diameters and in physical units

TbSp = mean(diams);%mean structure thickness
TbSpSTD = std(diams);%standard deviation of structure thicknesses

TN = 1/TbSp;

%find TMD and vBMD
if isfield(info,'Private_0029_1004')
    [densityMatrix junk] = calculateDensityFromDICOM(info,img);
    clear junk;
    TMD = mean(densityMatrix(find(bw)));
    vBMD = mean(densityMatrix(find(bwFilled)));
else
    TMD = 0;
    vBMD = 0;
end

% %do SMI as 6 * (BV * (dS/dr))/BS^2
% dr = 0.000001;
% shp = shpFromBW(bw);
% faces = shp.boundaryFacets;
% vertices = shp.Points;
% % figure;
% % plot(shp)
% % %     'repairing'
% % [vertices faces] = meshcheckrepair(vertices,faces,'meshfix');
% %     'unifying'
% % faces = meshreorient(vertices,faces);
% % close all
% %     'calculating vertex normals'
% vertexNormals = vertexNormal2(vertices,faces);%calculate vertex normals for expansion
% newVertices = vertices + dr*vertexNormals;%generate new vertex locations for different mesh
% BS = meshSurfaceArea(vertices,faces);
% dS = meshSurfaceArea(newVertices,faces);
% dS = abs(BS - dS);
SMI = 0;%(6 * BV * (dS/dr)) / BS^2;

cc = bwconncomp(bw);
numPixels = cellfun(@numel,cc.PixelIdxList);
[biggest,idx] = max(numPixels);
bw = false(size(bw));
bw(cc.PixelIdxList{idx}) = true;
                    
[connectivity label] = imEuler3d(bw,26);%calculate Euler characteristic of foreground structure
ConnD = (1-connectivity) / TV;

out = {TV,...
    BV,...
    BVTV,...
    ConnD,...
    SMI,...
    TbTh,...
    TbThSTD,...
    TbSp,...
    TbSpSTD,...
    TN,...
    vBMD,...
    TMD,...
    info.SliceThickness};
outHeader = {'Total Volume (mm^3)',...
    'Vessel Volume (mm^3)',...
    'VVTV',...
    'Connectivity',...
    'Structural Model Index',...
    'Mean Vessel Thickness (mm)',...
    'Vessel Thickness Standard Deviation (mm)',...
    'Mean Vessel Spacing (mm)',...
    'Vessel Spacing Standard Deviation (mm)',...
    'Vessel Number',...
    'Volumetric Bone Mineral Density (mgHA/cm^3)',...
    'Tissue Mineral Density(mgHA/cm^3)',...
    'Voxel Dimension (mm^3)'...
    };