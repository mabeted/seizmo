function [x,y,z]=geographic2xyz(lat,lon,depth,ellipsoid)
%GEOGRAPHIC2XYZ    Converts coordinates from geographic to cartesian
%
%    Usage:    [x,y,z]=geographic2xyz(lat,lon,depth)
%              [x,y,z]=geographic2xyz(lat,lon,depth,[a f])
%
%    Description: [X,Y,Z]=GEOGRAPHIC2XYZ(LAT,LON,DEPTH) converts
%     coordinates in geographic latitude, longitude, depth to Earth-
%     centered, Earth-fixed (ECEF).  LAT and LON are in degrees.  DEPTH, X,
%     Y, Z must be/are in kilometers.  The reference ellipsoid is assumed
%     to be WGS-84.
%
%     GEOGRAPHIC2XYZ(LAT,LON,DEPTH,[A F]) allows specifying the ellipsoid
%     parameters A (equatorial radius in kilometers) and F (flattening).
%     This is compatible with Matlab's Mapping Toolbox function ALMANAC.
%
%    Notes:
%     - the ECEF coordinate system has the X axis passing through the
%       equator at the prime meridian, the Z axis through the north pole
%       and the Y axis through the equator at 90 degrees longitude.
%
%    Examples:
%     Get out of the geographic coordinate system and into cartesian:
%      [x,y,z]=geographic2xyz(lat,lon,depth)
%
%    See also: XYZ2GEOGRAPHIC, GEOCENTRIC2XYZ, XYZ2GEOCENTRIC,
%              GEOGRAPHIC2GEOCENTRIC, GEOCENTRIC2GEOGRAPHIC

%     Version History:
%        Oct. 14, 2008 - initial version
%        Nov. 10, 2008 - scalar expansion, doc update
%        Apr. 23, 2009 - fix nargchk for octave, move usage up
%        Sep.  5, 2009 - minor doc update
%        Nov. 13, 2009 - name change: geodetic to geographic, minor doc fix
%        May   3, 2010 - better checking
%        Feb. 11, 2011 - mass nargchk fix
%
%     Written by Garrett Euler (ggeuler at wustl dot edu)
%     Last Updated Feb. 11, 2011 at 15:05 GMT

% todo:

% require 3 or 4 inputs
error(nargchk(3,4,nargin));

% default - WGS-84 Reference Ellipsoid
if(nargin==3 || isempty(ellipsoid))
    % a=radius at equator (major axis)
    % f=flattening
    a=6378.137;
    f=1/298.257223563;
else
    % manually specify ellipsoid (will accept almanac output)
    if(isreal(ellipsoid) && numel(ellipsoid)==2 && ellipsoid(2)<1)
        a=ellipsoid(1);
        f=ellipsoid(2);
    else
        error('seizmo:geographic2xyz:badEllipsoid',...
            ['Ellipsoid must a 2 element vector specifying:\n'...
            '[equatorial_km_radius flattening(<1)]']);
    end
end

% size up inputs
sx=size(lat); sy=size(lon); sz=size(depth);
nx=prod(sx); ny=prod(sy); nz=prod(sz);

% basic check inputs
if(~isreal(lat) || ~isreal(lon) || ~isreal(depth))
    error('seizmo:geographic2xyz:nonNumeric',...
        'All inputs must be numeric!');
elseif(any([nx ny nz]==0))
    error('seizmo:geographic2xyz:unpairedCoord',...
        'Coordinate inputs must be nonempty arrays!');
elseif((~isequal(sx,sy) && all([nx ny]~=1)) ||...
       (~isequal(sx,sz) && all([nx nz]~=1)) ||...
       (~isequal(sz,sy) && all([nz ny]~=1)))
    error('seizmo:geographic2xyz:unpairedCoord',...
        'Coordinate inputs must be scalar or equal sized arrays!');
end

% expand scalars
if(all([nx ny nz]==1))
    % do nothing
elseif(all([nx ny]==1))
    lat=repmat(lat,sz); lon=repmat(lon,sz);
elseif(all([nx nz]==1))
    lat=repmat(lat,sy); depth=repmat(depth,sy);
elseif(all([ny nz]==1))
    lon=repmat(lon,sx); depth=repmat(depth,sx);
elseif(nx==1)
    lat=repmat(lat,sz);
elseif(ny==1)
    lon=repmat(lon,sz);
elseif(nz==1)
    depth=repmat(depth,sy);
end

% vectorized setup
e2=f*(2-f);
sinlat=sind(lat);
achi=a./sqrt(1-e2.*sinlat.^2);
c=(achi-depth).*cosd(lat);

% convert to xyz
x=c.*cosd(lon);
y=c.*sind(lon);
z=(achi.*(1-e2)-depth).*sinlat;

end
