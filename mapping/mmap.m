function [varargout]=mmap(varargin)
%MMAP    Creates an M_Map map
%
%    Usage:    mmap()
%              mmap(...,'stations',[lat lon],...)
%              mmap(...,'stationmarker',symstr,...)
%              mmap(...,'stationmarkersize',val,...)
%              mmap(...,'events',[lat lon],...)
%              mmap(...,'eventmarker',symstr,...)
%              mmap(...,'eventmarkersize',symstr,...)
%              mmap(...,'gshhs',res,...)
%              mmap(...,'proj',proj,...)
%              mmap(...,'projopt',{'opt',val,...},...)
%              mmap(...,'gridopt',{'opt',val,...},...)
%              mmap(...,'fgcolor',color,...)
%              mmap(...,'bgcolor',color,...)
%              mmap(...,'sea',color,...)
%              mmap(...,'land',color,...)
%              mmap(...,'border',color,...)
%              mmap(...,'axis',ax,...)
%              ax=mmap(...)
%
%    Description: MMAP() creates a global map using the Hammer
%     projection.  The map is quite basic without topography but does
%     include coastlines.  Land is colored green and the oceans blue.  The
%     figure is set to black and the map boundary is white.
%
%     MMAP(...,'STATIONS',[LAT LON],...) sets the station locations
%     to plot in the map.  The stations will be drawn as yellow circles.
%
%     MMAP(...,'STATIONMARKER',SYMSTR,...) sets the station symbol
%     type and color.  The default SYMSTR is 'yo' which stands for yellow
%     circle.  SYMSTR can be any combination of the following color and
%     symbol characters:
%
%         COLOR              SYMBOL
%           b     blue          .     point
%           g     green         o     circle
%           r     red           x     x-mark
%           c     cyan          +     plus
%           m     magenta       *     star
%           y     yellow        s     square
%           k     black         d     diamond
%           w     white         v     triangle (down)
%                               ^     triangle (up)
%                               <     triangle (left)
%                               >     triangle (right)
%                               p     pentagram
%                               h     hexagram
%
%     MMAP(...,'STATIONMARKERSIZE',VAL,...) sets the station marker
%     size to VAL.  The default is [], which uses the default size
%     determined dynamically (I think).
%
%     MMAP(...,'EVENTS',[LAT LON],...) sets the event locations to
%     plot in the map.  The events will be drawn as red stars.
%
%     MMAP(...,'EVENTMARKER',SYMSTR,...) sets the station symbol
%     type and color.  The default SYMSTR is 'rp' which stands for red
%     pentagram.  See option STATIONMARKER for other possibilities.
%
%     MMAP(...,'EVENTMARKERSIZE',VAL,...) sets the event marker
%     size to VAL.  The default is 75 as this scales better with the
%     defaults.
%
%     MMAP(...,'GSHHS',RES,...) sets the GSHHS coastline and
%     political boundaries resolution.  The values can be 'c', 'l', 'i',
%     'h', 'f', or 'o' (for 'off').  The default GSHHS resolution is 'o'
%     (off) which calls M_COAST and does not draw political borders.
%
%     MMAP(...,'PROJ',PROJ,...) defines the map projection.  See
%     M_PROJ('SET') for possible projections.  The default PROJ is
%     'Robinson'.
%
%     MMAP(...,'PROJOPT',{'opt',val,...},...) passes additional
%     options to M_PROJ (like the lat/lon boundaries of the map).  The
%     options must be wrapped in a cell array!  See M_PROJ('get',PROJ) for
%     a list of possible options for the set projection (see 'PROJ' option
%     for the default projection and altering it).  The default is no
%     additional options, which will create a global map.
%
%     MMAP(...,'GRIDOPT',{'opt',val,...},...) passes options to
%     M_GRID (like the lat/lon ticks of the map, etc).  The options must be
%     wrapped in a cell array!  See M_GRID('get') for a list of possible
%     options and M_GRID('set') for their defaults.  The default is no
%     options.
%
%     MMAP(...,'FGCOLOR',COLOR,...) specifies the foreground color
%     of the map.  The default is 'w'.  If BGCOLOR is specified and FGCOLOR
%     is not, then FGCOLOR will be set using INVERTCOLOR.
%
%     MMAP(...,'BGCOLOR',COLOR,...) specifies the background color
%     of the map.  The default is 'k'.  If FGCOLOR is specified and BGCOLOR
%     is not, then BGCOLOR will be set using INVERTCOLOR.
%
%     MMAP(...,'SEA',COLOR,...) specifies the color of the sea in
%     the map.  The default is [.3 .6 1].
%
%     MMAP(...,'LAND',COLOR,...) specifies the color of the land in
%     the map.  The default is [.4 .6 .2].
%
%     MMAP(...,'BORDER',COLOR,...) specifies the color of the
%     political borders in the map.  The default is [.5 0 0].
%
%     MMAP(...,'PARENT',AX,...)  sets the axes to draw in.  This is
%     useful for subplots, guis, etc.  The default draws the map in a new
%     figure.  Note that this allows plotting stations/events to an
%     existing map drawn by MMAP but only if the axes' hold state on 'on'.
%
%     AX=MMAP(DATA) returns the axes handle for the map.
%
%    Notes:
%
%    Examples:
%     Show a grid of stations in a map with fancy border:
%      [stla,stlo]=meshgrid(3:13,10:15);
%      mmap('st',[stla(:) stlo(:)],...
%                   'po',{'lat',[-40 40],'lon',[-30 60]},...
%                   'go',{'box','fancy'})
%
%    See also: M_PROJ, M_GRID, M_GSHHS, M_SCATTER, MAPFEATURE, RAISEFANCY

%     Version History:
%        July 13, 2010 - initial version
%        Aug. 27, 2010 - adapts to figure color if no color is given and an
%                        axis is given, improved axis usage, Robinson proj
%        Aug. 30, 2010 - allow individual sizing & coloring of st/ev
%        Sep. 16, 2010 - changed eventmarkersize to 75 for looks
%        Oct. 10, 2010 - changed eventmarkersize to 150 for looks
%        Feb. 10, 2011 - namechange: maplocations => mmap, h1 line changed
%        Mar.  6, 2011 - fix bug in longitude wrapping
%        June 14, 2011 - add fgc/bgc option shortcuts, added code to allow
%                        drawing stations/events on an existing mmap
%
%     Written by Garrett Euler (ggeuler at wustl dot edu)
%     Last Updated June 14, 2011 at 20:30 GMT

% todo:

% check nargin
if(mod(nargin,2))
    error('seizmo:mmap:badNumInputs',...
        'Unpaired Option/Value!');
end

% access to m_map globals for map boundaries
global MAP_VAR_LIST

% option defaults
varargin=[{'st' [] 'sm' 'yo' 'ss' [] 'ev' [] 'em' 'rp' 'es' 150 'g' 'o' ...
    'p' 'robinson' 'po' [] 'go' [] 'fg' [] 'bg' [] 's' [.3 .6 1] ...
    'l' [.4 .6 .2] 'b' [.5 0 0] 'a' []} varargin];

% check options
if(~iscellstr(varargin(1:2:end)))
    error('seizmo:mmap:badOption',...
        'All Options must be specified with a string!');
end
for i=1:2:numel(varargin)
    % skip empty by default (but still checking option exists)
    skip=false;
    if(isempty(varargin{i+1})); skip=true; end
    val=varargin{i+1};
    
    % check option is available
    switch lower(varargin{i})
        case {'stations' 'sta' 'st'}
            if(skip)
                stla=[];
                stlo=[];
            elseif(isreal(val) && ndims(val)==2 && size(val,2)==2)
                stla=val(:,1);
                stlo=val(:,2);
            else
                error('seizmo:mmap:badInput',...
                    'STATIONS option must be [LAT LON] in degrees!');
            end
        case {'events' 'ev' 'e'}
            if(skip)
                evla=[];
                evlo=[];
            elseif(isreal(val) && ndims(val)==2 && size(val,2)==2)
                evla=val(:,1);
                evlo=val(:,2);
            else
                error('seizmo:mmap:badInput',...
                    'EVENTS option must be [LAT LON] in degrees!');
            end
        case {'stationmarker' 'stm' 'sm'}
            if(skip); continue; end
            if(ischar(val) && numel(val)<3)
                stm=val;
            elseif(isreal(val) && size(val,2)==3 && all(val>=0 & val<=1))
                stm=val;
            else
                error('seizmo:mmap:badInput',...
                    'STATIONMARKER must be a 1 or 2 char string!');
            end
        case {'eventnmarker' 'evm' 'em'}
            if(skip); continue; end
            if(ischar(val) && numel(val)<3)
                evm=val;
            elseif(isreal(val) && size(val,2)==3 && all(val>=0 & val<=1))
                evm=val;
            else
                error('seizmo:mmap:badInput',...
                    'EVENTMARKER must be a 1 or 2 char string!');
            end
        case {'eventmarkersize' 'eventsize' 'evs' 'evms' 'ems' 'es'}
            if(skip)
                evs=val;
            elseif(isreal(val))
                evs=val;
            else
                error('seizmo:mmap:badInput',...
                    'EVENTMARKERSIZE must be a positive real scalar!');
            end
        case {'stationmarkersize' 'stationsize' 'sts' 'stms' 'sms' 'ss'}
            if(skip)
                sts=val;
            elseif(isreal(val))
                sts=val;
            else
                error('seizmo:mmap:badInput',...
                    'STATIONMARKERSIZE must be a positive real scalar!');
            end
        case {'gshhs' 'res' 'g'}
            if(skip); continue; end
            if(ischar(val) && numel(val)==1 ...
                    && any(strcmpi(val,{'o' 'c' 'l' 'i' 'h' 'f'})))
                gshhs=lower(val);
            else
                error('seizmo:mmap:badInput',...
                    'GSHHS option must be c, l, i, h, or f !');
            end
        case {'projection' 'proj' 'p'}
            if(skip); continue; end
            if(ischar(val) && ndims(val)==2 && size(val,1)==1)
                proj=lower(val);
            else
                error('seizmo:mmap:badInput',...
                    'PROJECTION option must be a string!');
            end
        case {'projopt' 'popt' 'po'}
            if(skip)
                popt={};
            elseif(iscell(val) && iscellstr(val(1:2:end)))
                popt=val;
            else
                error('seizmo:mmap:badInput',...
                    ['PROJOPT option must be a cell array of ' ...
                    '''option''/value pairs!']);
            end
        case {'gridopt' 'gopt' 'go'}
            if(skip)
                gopt={};
            elseif(iscell(val) && iscellstr(val(1:2:end)))
                gopt=val;
            else
                error('seizmo:mmap:badInput',...
                    ['GRIDOPT option must be a cell array of ' ...
                    '''option''/value pairs!']);
            end
        case {'fgcolor' 'fg' 'fgc'}
            if(skip)
                fg=[];
            elseif(ischar(val) ...
                    || (isreal(val) && isequal(size(val),[1 3])))
                fg=val;
            else
                error('seizmo:mmap:badInput',...
                    'FGCOLOR must be a colorname or RGB triplet!');
            end
        case {'bgcolor' 'bg' 'bgc'}
            if(skip)
                bg=[];
            elseif(ischar(val) ...
                    || (isreal(val) && isequal(size(val),[1 3])))
                bg=val;
            else
                error('seizmo:mmap:badInput',...
                    'BGCOLOR must be a colorname or RGB triplet!');
            end
        case {'seacolor' 'sea' 's'}
            if(skip); continue; end
            if(ischar(val) ...
                    || (isreal(val) && isequal(size(val),[1 3])))
                sea=val;
            else
                error('seizmo:mmap:badInput',...
                    'SEACOLOR must be a colorname or RGB triplet!');
            end
        case {'landcolor' 'land' 'l'}
            if(skip); continue; end
            if(ischar(val) ...
                    || (isreal(val) && isequal(size(val),[1 3])))
                land=val;
            else
                error('seizmo:mmap:badInput',...
                    'LANDCOLOR must be a colorname or RGB triplet!');
            end
        case {'bordercolor' 'border' 'b'}
            if(skip); continue; end
            if(ischar(val) ...
                    || (isreal(val) && isequal(size(val),[1 3])))
                border=val;
            else
                error('seizmo:mmap:badInput',...
                    'BORDERCOLOR must be a colorname or RGB triplet!');
            end
        case {'axis' 'ax' 'a' 'parent' 'pa' 'par'}
            if(skip)
                ax=[];
            else
                ax=val;
            end
        otherwise
            error('seizmo:mmap:badOption',...
                'Unknown Option: %s',varargin{i});
    end
end

% fix fg/bg colors
if(isempty(fg))
    if(isempty(bg))
        if(isempty(ax) || ~isscalar(ax) || ~isreal(ax) ...
                || ~ishandle(ax) || ~strcmp('axes',get(ax,'type')))
            fg='w'; bg='k';
        else
            bg=get(get(ax,'parent'),'color');
            fg=invertcolor(bg,true);
        end
    else
        fg=invertcolor(bg,true);
    end
elseif(isempty(bg))
    bg=invertcolor(fg,true);
end

% convert colornames
if(ischar(fg)); fg=name2rgb(fg); end
if(ischar(bg)); bg=name2rgb(bg); end
if(ischar(sea)); sea=name2rgb(sea); end
if(ischar(land)); land=name2rgb(land); end
if(ischar(border)); border=name2rgb(border); end

% setup axis
if(isempty(ax) || ~isscalar(ax) || ~isreal(ax) ...
        || ~ishandle(ax) || ~strcmp('axes',get(ax,'type')))
    % new figure
    fh=figure('color',bg);
    ax=axes('parent',fh);
    held=false;
else
    axes(ax);
    % use axes if held and an mmap map
    if(ishold(ax) && strcmpi(get(ax,'tag'),'locationmap'))
        held=true;
    else % clear these axes
        held=false;
        h=get(ax,'children'); delete(h);
        h=findobj(get(get(ax,'parent'),'children'),'peer',ax); delete(h);
    end
end

% plot map
% - test if options will update a plot or draw new
%   - mixed m_coast & m_gshhs draws new
% - could we delete and redraw certain things?
if(~held)
    m_proj(proj,popt{:});
    set(ax,'color',sea);
    if(strcmpi(gshhs,'o'))
        m_coast('patch',land);
    else
        m_gshhs([gshhs 'c'],'patch',land);
        m_gshhs([gshhs 'b'],'color',border);
    end
    m_grid('color',fg,gopt{:});
end

% hackery to color oceans at large when the above fails
set(findobj(ax,'tag','m_grid_color'),'facecolor',sea);

% wrap longitudes to plot
while(any(stlo-MAP_VAR_LIST.longs(2)>0))
    stlo(stlo>MAP_VAR_LIST.longs(2))=...
        stlo(stlo>MAP_VAR_LIST.longs(2))-360; %#ok
end
while(any(stlo-MAP_VAR_LIST.longs(1)<0))
    stlo(stlo<MAP_VAR_LIST.longs(1))=...
        stlo(stlo<MAP_VAR_LIST.longs(1))+360; %#ok
end
while(any(evlo-MAP_VAR_LIST.longs(2)>0))
    evlo(evlo>MAP_VAR_LIST.longs(2))=...
        evlo(evlo>MAP_VAR_LIST.longs(2))-360; %#ok
end
while(any(evlo-MAP_VAR_LIST.longs(1)<0))
    evlo(evlo<MAP_VAR_LIST.longs(1))=...
        evlo(evlo<MAP_VAR_LIST.longs(1))+360; %#ok
end

% plot locations
hold(ax,'on');
h=m_scatter(ax,evlo,evla,evs,evm,'filled','markeredgecolor','k');
set(h,'tag','events');
h=m_scatter(ax,stlo,stla,sts,stm,'filled','markeredgecolor','k');
set(h,'tag','stations');
if(~held); hold(ax,'off'); end

% return figure handle
set(ax,'tag','locationmap');
if(nargout); varargout{1}=ax; end

end
