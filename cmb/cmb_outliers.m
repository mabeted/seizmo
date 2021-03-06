function [results]=cmb_outliers(results,odir,figdir)
%CMB_OUTLIERS    Outlier analysis of core-diffracted data
%
%    Usage:    results=cmb_outliers(results)
%              results=cmb_outliers(results,odir)
%              results=cmb_outliers(results,odir,figdir)
%
%    Description:
%     RESULTS=CMB_OUTLIERS(RESULTS) provides an interface for graphically
%     removing arrival time and amplitude outliers from the core-diffracted
%     wave analysis RESULTS struct generated by either CMB_1ST_PASS,
%     CMB_CLUSTERING or CMB_2ND_PASS.  The user is also allowed to select
%     stations in a specific region based on limiting by azimuth and
%     distance.  Plots and info are saved during the analysis by the user.
%
%     RESULTS=CMB_OUTLIERS(RESULTS,ODIR) sets the output directory
%     where the figures and RESULTS struct is saved.  By default ODIR is
%     '.' (the current directory.
%
%     RESULTS=CMB_OUTLIERS(RESULTS,ODIR,FIGDIR) allows saving figures to a
%     different directory than ODIR (where the RESULTS struct is saved).
%
%    Notes:
%     - Outliers are reset each time CMB_OUTLIERS is ran on a RESULTS
%       struct.
%
%    Examples:
%     % Typical alignment and refinement workflow:
%     results=cmb_1st_pass;
%     results=cmb_clustering(results);
%     results=cmb_outliers(results);
%
%    See also: PREP_CMB_DATA, CMB_1ST_PASS, CMB_2ND_PASS, SLOWDECAYPAIRS,
%              SLOWDECAYPROFILES, MAP_CMB_PROFILES, CMB_CLUSTERING

%     Version History:
%        Dec. 12, 2010 - added docs
%        Jan.  6, 2011 - catch empty axis handle breakage
%        Jan. 13, 2011 - output ground units in .adjustclusters field
%        Jan. 16, 2011 - split off clustering to cmb_clustering, menu
%                        rather than forcing user to cycle through
%        Jan. 18, 2011 - .time field, no setting groups as bad
%        Jan. 26, 2011 - no travel time corrections for synthetics, use 2
%                        digit cluster numbers, update for 2 plot arrcut
%        Jan. 29, 2011 - prepend datetime to output names, fix Sdiff
%                        corrections bug
%        Jan. 31, 2011 - odir & figdir inputs
%        Feb. 12, 2011 - include snr-based arrival time error
%        Mar.  6, 2011 - coloring in arrcut/ampcut, undo all button
%        Mar. 10, 2011 - distance/azimuth window
%        Mar. 30, 2011 - minor doc update
%        Apr.  3, 2011 - update .time field of skipped
%        Apr. 22, 2011 - update for finalcut field
%        May  19, 2011 - undo works now
%
%     Written by Garrett Euler (ggeuler at wustl dot edu)
%     Last Updated May  19, 2011 at 13:35 GMT

% todo:

% check nargin
error(nargchk(1,3,nargin));

% check results
error(check_cmb_results(results));

% default odir & figdir
if(nargin<2 || isempty(odir)); odir='.'; end
if(nargin<3 || isempty(figdir)); figdir=odir; end

% check odir & figdir
if(~isstring(odir))
    error('seizmo:cmb_outliers:badInput',...
        'ODIR must be a string!');
elseif(~isstring(figdir))
    error('seizmo:cmb_outliers:badInput',...
        'FIGDIR must be a string!');
end

% make sure odir/figdir exists (create it if it does not)
[ok,msg,msgid]=mkdir(odir);
if(~ok)
    warning(msgid,msg);
    error('seizmo:cmb_outliers:pathBad',...
        'Cannot create directory: %s',odir);
end
[ok,msg,msgid]=mkdir(figdir);
if(~ok)
    warning(msgid,msg);
    error('seizmo:cmb_outliers:pathBad',...
        'Cannot create directory: %s',figdir);
end

% loop over each event
for i=1:numel(results)
    % display name
    disp(results(i).runname);
    
    % time (for skipped)
    results(i).time=datestr(now);
    
    % abandon events we skipped
    if(isempty(results(i).useralign)); continue; end
    
    % arrival & amplitude info
    [dd,az,ev,st]=getheader(results(i).useralign.data,...
        'gcarc','az','ev','st');
    arr=results(i).useralign.solution.arr;
    if(results(i).synthetics)
        carr=arr;
    else
        switch results(i).phase
            case 'Pdiff'
                carr=arr-results(i).corrections.ellcor...
                    -results(i).corrections.crucor.prem...
                    -results(i).corrections.mancor.hmsl06p.upswing;
            case {'SHdiff' 'SVdiff'}
                carr=arr-results(i).corrections.ellcor...
                    -results(i).corrections.crucor.prem...
                    -results(i).corrections.mancor.hmsl06s.upswing;
        end
    end
    snr=results(i).usersnr.snr;
    snr=snr(snr>=results(i).usersnr.snrcut);
    snr(results(i).userwinnow.cut)=[];
    if(isfield(results(i),'finalcut')); snr=snr(results(i).finalcut); end
    arrerr=sqrt((results(i).useralign.solution.arrerr).^2 ...
        +(max(1./results(i).filter.corners)...
        ./(2*pi).*snr2phaseerror(snr)).^2);
    amp=results(i).useralign.solution.amp;
    camp=amp./results(i).corrections.geomsprcor;
    amperr=results(i).useralign.solution.amperr;
    
    % default to all non-outliers
    results(i).outliers.bad=false(numel(results(i).useralign.data),1);
    
    % loop over good clusters
    for j=find(results(i).usercluster.good(:)')
        % current cluster index as a string
        sj=num2str(j,'%02d');
        
        % preallocate struct
        results(i).outliers.cluster(j).arrcut=...
            struct('bad',[],'cutoff',[]);
        results(i).outliers.cluster(j).ampcut=...
            struct('bad',[],'cutoff',[]);
        results(i).outliers.cluster(j).errcut=...
            struct('bad',[],'cutoff',[]);
        
        % loop until user is happy overall
        % with outlier analysis of this cluster
        happyoverall=false;
        arrcnt=0; ampcnt=0; errcnt=0; delazcnt=0;
        while(~happyoverall)
            % get current cluster population
            good=find(results(i).usercluster.T==j ...
                & ~results(i).outliers.bad);
            pop=numel(good);
            
            % require at least 2 members in good standing
            % - otherwise set remaining as outliers and skip
            if(pop<2)
                warning('seizmo:cmb_outliers:tooFewGood',...
                    ['Cluster ' sj ' has <2 good members. Skipping!']);
                results(i).outliers.bad(good)=true;
                happyoverall=true;
                continue;
            end
            
            % ask user what to do
            choice=menu(...
                ['CLUSTER ' sj ': Remove what outliers?'],...
                'Arrival Time',...
                'Arrival Time Error',...
                'Amplitude',...
                'Azimuth/Distance',...
                'Undo All',...
                'Continue');
            
            % action based on choice
            switch choice
                case 1 % arr
                    arrcnt=arrcnt+1;
                    [bad,cutoff,ax]=...
                        arrcut(dd(good),carr(good),[],1,arrerr(good),[],...
                        z2c(az(good),hsv(64),[0 360]));
                    results(i).outliers.bad(good(bad))=true;
                    results(i).outliers.cluster(j).arrcut.bad{arrcnt}=good(bad);
                    results(i).outliers.cluster(j).arrcut.cutoff(arrcnt)=cutoff;
                    if(ishandle(ax(1)))
                        saveas(get(ax(1),'parent'),fullfile(figdir,...
                            [datestr(now,30) '_' results(i).runname ...
                            '_cluster_' sj '_arrcut_' num2str(arrcnt) ...
                            '.fig']));
                        close(get(ax(1),'parent'));
                    end
                case 2 % arrerr
                    errcnt=errcnt+1;
                    [bad,cutoff,ax]=errcut(dd(good),arrerr(good));
                    results(i).outliers.bad(good(bad))=true;
                    results(i).outliers.cluster(j).errcut.bad{errcnt}=good(bad);
                    results(i).outliers.cluster(j).errcut.cutoff(errcnt)=cutoff;
                    if(ishandle(ax))
                        saveas(get(ax,'parent'),fullfile(figdir,...
                            [datestr(now,30) '_' results(i).runname ...
                            '_cluster_' sj '_errcut_' num2str(errcnt) ...
                            '.fig']));
                        close(get(ax,'parent'));
                    end
                case 3 % amp
                    ampcnt=ampcnt+1;
                    [bad,cutoff,ax]=ampcut(dd(good),camp(good),[],1,amperr(good),[],...
                        z2c(az(good),hsv(64),[0 360]));
                    results(i).outliers.bad(good(bad))=true;
                    results(i).outliers.cluster(j).ampcut.bad{ampcnt}=good(bad);
                    results(i).outliers.cluster(j).ampcut.cutoff(ampcnt)=cutoff;
                    if(ishandle(ax))
                        saveas(get(ax,'parent'),fullfile(figdir,...
                            [datestr(now,30) '_' results(i).runname ...
                            '_cluster_' sj '_ampcut_' num2str(ampcnt) ...
                            '.fig']));
                        close(get(ax,'parent'));
                    end
                case 4 % distance/azimuth
                    delazcnt=delazcnt+1;
                    [bad,azlim,ddlim,ax]=delazcut(ev(1,1:2),st(good,1:2),...
                        [],[],results(i).usercluster.color(j,:));
                    results(i).outliers.bad(good(bad))=true;
                    results(i).outliers.cluster(j).delazcut.bad{delazcnt}=good(bad);
                    results(i).outliers.cluster(j).delazcut.azlim{delazcnt}=azlim;
                    results(i).outliers.cluster(j).delazcut.ddlim{delazcnt}=ddlim;
                    if(ishandle(ax))
                        saveas(get(ax,'parent'),fullfile(figdir,...
                            [datestr(now,30) '_' results(i).runname ...
                            '_cluster_' sj '_delazcut_' num2str(delazcnt) ...
                            '.fig']));
                        close(get(ax,'parent'));
                    end
                case 5 % undo all
                    results(i).outliers.cluster(j).arrcut=...
                        struct('bad',[],'cutoff',[]);
                    results(i).outliers.cluster(j).ampcut=...
                        struct('bad',[],'cutoff',[]);
                    results(i).outliers.cluster(j).errcut=...
                        struct('bad',[],'cutoff',[]);
                    arrcnt=0; ampcnt=0; errcnt=0;
                    results(i).outliers.bad(...
                        results(i).usercluster.T==j)=false;
                case 6 % continue
                    happyoverall=true;
                    continue;
            end
        end
    end
    
    % time
    results(i).time=datestr(now);
    
    % save results
    tmp=results(i);
    save(fullfile(odir,[datestr(now,30) '_' results(i).runname ...
        '_outliers_results.mat']),'-struct','tmp');
end

end
