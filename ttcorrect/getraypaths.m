function [paths]=getraypaths(phase,mod,evla,evlo,evdp,stla,stlo)
%GETRAYPATHS    Returns seismic phase paths for a set of stations
%
%    Usage:    paths=getraypaths(phase,mod,evla,evlo,evdp,stla,stlo)
%
%    Description:
%     PATHS=GETRAYPATHS(PHASE,MOD,EVLA,EVLO,EVDP,STLA,STLO) returns a
%     struct array containing phase paths for each PHASE/MODEL/EQ/STA pair.
%     PHASE should be a char or cellstr array and is case sensitive (uses
%     TauP to parse the phase name).  MOD must be a 1D model name
%     recognized by TauP.  Lat/Lon inputs must be in degrees.  Depth is in
%     kilometers (note that this is not like the SAC format)!
%
%     This just calls TAUPPATH in a loop.
%
%    Notes:
%
%    Examples:
%     % Get some phase paths corresponding to a dataset:
%     [stla,stlo,evla,evlo,evdp]=getheader(data,'stla','stlo',...
%                                          'evla','evlo','evdp');
%     evdp=evdp/1000; % m2km
%     paths=getraypaths('P','prem',evla,evlo,evdp,stla,stlo);
%
%    See also: TAUPPATH, MANCOR, CRUST2LESS_RAYPATHS, TRIM_DEPTHS_RAYPATHS,
%              EXTRACT_UPSWING_RAYPATHS

%     Version History:
%        May  31, 2010 - initial version
%        June  3, 2010 - verbose support
%        June  4, 2010 - paths reshapes to match inputs
%        Mar.  7, 2011 - don't cover up error for debugging
%        May  19, 2011 - updated error message to reflect the usual issue
%
%     Written by Garrett Euler (ggeuler at wustl dot edu)
%     Last Updated May  19, 2011 at 13:45 GMT

% todo:

% check nargin
error(nargchk(7,7,nargin));

% check inputs
if(ischar(phase)); phase=cellstr(phase); end
if(ischar(mod)); mod=cellstr(mod); end
if(~all(cellfun('isreal',{evla evlo evdp stla stlo})))
    error('seizmo:getraypaths:badLocation',...
        'All lat/lon/depth values must be real valued!');
elseif(~iscellstr(phase))
    error('seizmo:getraypaths:badPhase',...
        'PHASE must be char/cellstr array!');
elseif(~iscellstr(mod))
    error('seizmo:getraypaths:badModel',...
        'MOD must be char/cellstr array!');
elseif(~isequalsizeorscalar(phase,mod,evla,evlo,evdp,stla,stlo))
    error('seizmo:getraypaths:badSize',...
        'All inputs must be scalar or equal-sized!');
end

% expand scalars
[evla,evlo,evdp,stla,stlo,mod,phase]=expandscalars(...
    evla,evlo,evdp,stla,stlo,mod,phase);
nph=numel(evla);

% fix out-of-range lat/lon
[stla,stlo]=fixlatlon(stla,stlo);
[evla,evlo]=fixlatlon(evla,evlo);

% geographic to geocentric lat
evla=geographic2geocentriclat(evla);
stla=geographic2geocentriclat(stla);

% verbose
verbose=seizmoverbose;
if(verbose)
    disp('Getting Ray Path(s)');
    print_time_left(0,nph)
end

% loop over each set
try
    i=nph;
    tmp=tauppath('ph',phase{i},'mod',mod{i},'dep',evdp(i),...
        'ev',[evla(i) evlo(i)],'st',[stla(i) stlo(i)]);
    if(isempty(tmp))
        error('seizmo:getraypaths:badPath',...
            ['Could not retrieve path for EQ/STA pair: %d\n' ...
            'Maybe you do not have your ~/.taup file correct?'],i);
    end
    paths(i)=tmp(1); % return only the first arrival for each set
    if(verbose); print_time_left(1,nph); end
    for i=1:nph-1
        tmp=tauppath('ph',phase{i},'mod',mod{i},'dep',evdp(i),...
            'ev',[evla(i) evlo(i)],'st',[stla(i) stlo(i)]);
        if(isempty(tmp))
            error('seizmo:getraypaths:badPath',...
                'Could not retrieve path for EQ/STA pair: %d',i);
        end
        paths(i)=tmp(1); % return only the first arrival for each set
        if(verbose); print_time_left(i+1,nph); end
    end
    
    % reshape to match input size
    paths=reshape(paths,size(evla));
catch
    error(lasterror);
end

end
