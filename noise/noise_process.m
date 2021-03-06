function []=noise_process(indir,outdir,steps,varargin)
%NOISE_PROCESS    Performs processing of seismic data for noise analysis
%
%    Usage:    noise_process(indir,outdir)
%              noise_process(indir,outdir,steps)
%              noise_process(indir,outdir,steps,'opt1',val,...,'optN',val)
%
%    Description:
%     NOISE_PROCESS(INDIR,OUTDIR) processes the data under the directory
%     INDIR using noise cross correlation methods.  The resulting data are
%     written to OUTDIR.  The following techniques are done on the input
%     dataset:
%      ( 1) remove dead records (no change in recorded value)
%      ( 2) remove short records (spanning less than 70% of time section)
%      ( 3) remove mean & trend
%      ( 4) taper (first/last 1%)
%      ( 5) resample to 1 sample/sec
%      ( 6) remove polezero response (displacement, lp taper: [.004 .006])
%      ( 7) NOT IMPLEMENTED
%      ( 8) rotate horizontals to North/East (removes unpaired)
%      ( 9) t-domain normalize (3-15s & 15-100s moving average)
%      (10) f-domain normalize (2mHz moving average)
%      (11) correlate (keep +/-4000s lagtime)
%      (12) rotate correlations into <RR, RT, TR, TT>
%     See below for details on how to alter or skip some of these steps.
%
%     NOISE_PROCESS(INDIR,OUTDIR,STEPS) only does the processing steps
%     indicated in STEPS.  STEPS should be a vector of numbers
%     corresponding to valid steps given above.  The default is [] which
%     does all of the above steps.
%
%     NOISE_PROCESS(INDIR,OUTDIR,STEPS,'OPT1',VAL,...,'OPTN',VAL) allows
%     changing some of the noise correlation parameters.  The following are
%     configurable:
%      MINIMUMLENGTH - minimum length of records in % of time section [70]
%      TAPERWIDTH - % width of step 4 taper relative to record length [1]
%      TAPERTYPE - type of taper in step 4 []
%      TAPEROPTION - option for taper in step 4 []
%      SAMPLERATE - samplerate to synchronize records to in step 5 [1]
%      PZDB - polezero db to use in step 6 []
%      UNITS - ground units of records after polezero removal ['disp']
%      PZTAPERLIMITS - lowpass taper to stabilize pz removal [.004 .008]
%      TDSTYLE - time domain normalization style:
%                '1bit' - set amplitudes to +/-1
%                'clip' - clip values above some absolute value
%                ['ram'] - normalized using running-absolute mean
%      TDRMS - use TDCLIP x RMS for each record [true]
%      TDCLIP - sets clip for TDSTYLE='clip' [1]
%      TDWEIGHTBANDS - frequency bands for TDSTYLE='ram' weights
%                     [1/15 1/3; 1/100 1/15]
%                     (TUNED TO MINIMIZE TELESEISMIC EARTHQUAKES)
%      FDSTYLE - frequency domain normalization style:
%                '1bit' - set all amplitudes to 1 (horizontals are special)
%                ['ram'] - normalized using running absolute mean
%      FDWIDTH - width of frequency window for FDSTYLE='ram' in Hz [.002]
%      XCMAXLAG - maximum lag time of output correlograms in sec [4000]
%      TIMESTART - process time sections from this time on []
%      TIMEEND - process times sections before this time []
%      LATRNG - include stations in this latitude range []
%      LONRNG - include stations in this longitude range []
%      NETWORKS - include records with these network codes []
%      STATIONS - include records with these station codes []
%      STREAMS - include records with these stream codes []
%      COMPONENTS - include records with these component codes []
%      FILENAMES - limit processing to files with these filenames []
%      QUIETWRITE - quietly overwrite OUTDIR (default is false)
%
%    Notes:
%     - Good Noise Analysis References:
%        Bensen et al 2007, GJI, doi:10.1111/j.1365-246X.2007.03374.x
%        Yang et al 2007, GJI, doi:10.1111/j.1365-246X.2006.03203.x
%        Lin et al 2008, GJI, doi:10.1111/j.1365-246X.2008.03720.x
%        Harmon et al 2008, GRL, doi:10.1029/2008GL035387
%        Prieto et al 2009, JGR, doi:10.1029/2008JB006067
%        Ekstrom et al 2009, GRL, doi:10.1029/2009GL039131
%     - Steps 9 & 10 for horizontals currently require running step 8 on
%       the same run (if you forget it is automatically done for you).
%
%    Header changes: Varies with steps chosen...
%
%    Examples:
%     % Perform the first 3 steps of noise processing,
%     % writing out the resulting data of each step:
%     noise_process('raw','step1',1)
%     noise_process('step1','step2',2)
%     noise_process('step2','step3',3)
%     % This is great for prototyping and debugging!
%
%     % Skip the normalization steps:
%     noise_process('raw','xc',[1:8 11:12])
%
%     % Use non-overlapping 15-minute timesections, sampled
%     % at 5Hz to look at noise up to about 1.5Hz:
%     noise_setup('raw','15raw','l',15,'o',0);
%     noise_process('15raw','15xc5',[],'sr',5,'xcmaxlag',500)
%     % We adjusted the lag time b/c 15 minutes is 900 seconds.
%
%    See also: NOISE_SETUP, NOISE_STACK, NOISE_WORKFLOW

%     Version History:
%        Nov. 22, 2011 - initial version (only first 6 steps)
%        Nov. 29, 2011 - more steps, subsetting
%        Dec. 13, 2011 - fix output writing
%        Jan. 12, 2012 - correlogram subsetting, normalization
%        Jan. 24, 2012 - doc update, parameter parsing/checking, several
%                        parameters altered
%        Jan. 25, 2012 - drop 1bit+ram, ram is now multipass capable
%        Jan. 27, 2012 - allow filenames to be a cellstr array, minor
%                        improvement to string option handling, split
%                        reading of header and data for speed
%        Feb.  1, 2012 - all time operations are in utc, turn off checking,
%                        parallelization edits, fdpassband option gone
%
%     Written by Garrett Euler (ggeuler at wustl dot edu)
%     Last Updated Feb.  1, 2012 at 11:15 GMT

% todo:
% - what is behind the lp noise?
%   - response taper?
%   - spectral whitening? NO
%   - temp norm? NO
%   - xc?
%   - the data?

% check nargin
error(nargchk(2,inf,nargin));
if(nargin>=4 && ~mod(nargin,2))
    error('seizmo:noise_process:badInput',...
        'Unpaired option/value pair given!');
end

% default steps to all
if(nargin<3 || isempty(steps)); steps=1:12; end

% parse/check options
opt=noise_process_parameters(varargin{:});

% check directories
if(~ischar(indir) || ~isvector(indir))
    error('seizmo:noise_process:fileNotString',...
        'INDIR must be a string!');
end
if(~exist(indir,'dir'))
    error('seizmo:noise_process:dirConflict',...
        ['Input Directory: %s\n' ...
        'Does not exist (or is not a directory)!'],indir);
end
if(~ischar(outdir) || ~isvector(outdir))
    error('seizmo:noise_process:fileNotString',...
        'OUTDIR must be a string!');
end
if(exist(outdir,'file'))
    if(~exist(outdir,'dir'))
        error('seizmo:noise_process:dirConflict',...
            'Output Directory: %s\nIs a file!',outdir);
    end
    if(~opt.QUIETWRITE)
        fprintf('Output Directory: %s\nDirectory Exists!\n',outdir);
        reply=input('Overwrite? Y/N [N]: ','s');
        if(isempty(reply) || ~strncmpi(reply,'y',1))
            disp('Not overwriting!');
            return;
        end
        disp('Overwriting!');
    end
end

% directory separator
fs=filesep;

% parallel processing setup (up to 8 instances)
%matlabpool(4); % PARALLEL

% get year directories and time-section directories
dirs=xdir([indir fs]);
dirs=dirs([dirs.isdir]' & ~strncmp({dirs.name}','.',1)); % unhidden dirs
yrdir={dirs.name};
nyr=numel(yrdir);
tsdir=cell(size(yrdir));
for i=1:nyr
    dirs=xdir([indir fs yrdir{i}]);
    dirs=dirs([dirs.isdir]' & ~strncmp({dirs.name}','.',1)); % unhidden dir
    tsdir{i}={dirs.name};
end

% verbosity  (turn it off for the loop)
verbose=seizmoverbose(false);
if(verbose); disp('PROCESSING SEISMIC DATA FOR NOISE ANALYSIS'); end

% loop over years
for i=1:nyr
    % skip if outside user-defined time range
    if((~isempty(opt.TIMESTART) ...
            && str2double(yrdir{i})<opt.TIMESTART(1)) ...
            || (~isempty(opt.TIMEEND) ...
            && str2double(yrdir{i})>opt.TIMEEND(1)))
        continue;
    end
    
    % loop over time section directories
    for j=1:numel(tsdir{i}) % SERIAL
    %parfor j=1:numel(tsdir{i}) % PARALLEL
        % read the header
        try
            data=readheader(...
                strcat(indir,fs,yrdir{i},fs,tsdir{i}{j},fs,opt.FILENAMES));
            hvsplit=false;
        catch
            % no data...
            continue;
        end
        if(isempty(data)); continue; end
        
        % check if records are correlations
        [kuser0,kuser1]=getheader(data,'kuser0','kuser1');
        xc=ismember(kuser0,{'MASTER' 'SLAVE'}) ...
            & ismember(kuser1,{'MASTER' 'SLAVE'});
        if(all(xc)); isxc=true;
        elseif(all(~xc)); isxc=false;
        else
            error('seizmo:noise_process:mixedData',...
                ['Data contains both seismic records and ' ...
                'correlograms! This is NOT allowed.\nYou might try ' ...
                'using the FILENAMES option to limit input to one type.']);
        end
        if(isxc && any(steps<12)) % CAREFUL
            error('seizmo:noise_process:invalidProcess4xcdata',...
                'Cannot run earlier processing steps on correlograms!');
        end
        
        % proceed by data type
        if(isxc) % correlograms
            % Use directory name to check if within time limits
            % - parse start/end from the time section directory name
            times=getwords(tsdir{i}{j},'_');          % separate times
            tsbgn=str2double(getwords(times{1},'.')); % make numeric vector
            tsend=str2double(getwords(times{2},'.'));
            if((~isempty(opt.TIMESTART) ...
                    && timediff(opt.TIMESTART,tsend,'utc')<=0) ...
                    || (~isempty(opt.TIMEEND) ...
                    && timediff(opt.TIMEEND,tsbgn,'utc')>=0))
                continue;
            end
            
            % limit to the stations that the user allows
            % Note: check both fields!
            if(~isempty(opt.LATRNG))
                [stla,evla]=getheader(data,'stla','evla');
                data=data(stla>=min(opt.LATRNG) & stla<=max(opt.LATRNG) ...
                    & evla>=min(opt.LATRNG) & evla<=max(opt.LATRNG));
                if(isempty(data)); continue; end
            end
            if(~isempty(opt.LONRNG))
                [stlo,evlo]=getheader(data,'stlo','evlo');
                data=data(stlo>=min(opt.LONRNG) & stlo<=max(opt.LONRNG) ...
                    & evlo>=min(opt.LONRNG) & evlo<=max(opt.LONRNG));
                if(isempty(data)); continue; end
            end
            if(~isempty(opt.NETWORKS))
                [knetwk1,knetwk2]=getheader(data,'knetwk','kt0');
                data=data(ismember(lower(knetwk1),opt.NETWORKS) ...
                    & ismember(lower(knetwk2),opt.NETWORKS));
                if(isempty(data)); continue; end
            end
            if(~isempty(opt.STATIONS))
                [kstnm1,kstnm2]=getheader(data,'kstnm','kt1');
                data=data(ismember(lower(kstnm1),opt.STATIONS) ...
                    & ismember(lower(kstnm2),opt.STATIONS));
                if(isempty(data)); continue; end
            end
            if(~isempty(opt.STREAMS))
                [khole1,khole2]=getheader(data,'khole','kt2');
                data=data(ismember(lower(khole1),opt.STREAMS) ...
                    & ismember(lower(khole2),opt.STREAMS));
                if(isempty(data)); continue; end
            end
            if(~isempty(opt.COMPONENTS))
                [kcmpnm1,kcmpnm2]=getheader(data,'kcmpnm','kt3');
                data=data(ismember(lower(kcmpnm1),opt.COMPONENTS) ...
                    & ismember(lower(kcmpnm2),opt.COMPONENTS));
                if(isempty(data)); continue; end
            end
        else % seismic records
            % find/check time section limits
            [tsbgn,tsend]=getheader(data,'a utc','f utc');
            tsbgn=unique(cell2mat(tsbgn),'rows');
            tsend=unique(cell2mat(tsend),'rows');
            if(size(tsbgn,1)>1 || size(tsend,1)>1)
                error('seizmo:noise_process:inconsistentSetup',...
                    'Time window limits are inconsistent!');
            end
            
            % skip if outside user-defined time range
            if((~isempty(opt.TIMESTART) ...
                    && timediff(opt.TIMESTART,tsend,'utc')<=0) ...
                    || (~isempty(opt.TIMEEND) ...
                    && timediff(opt.TIMEEND,tsbgn,'utc')>=0))
                continue;
            end
            
            % limit to stations user allowed
            if(~isempty(opt.LATRNG))
                stla=getheader(data,'stla');
                data=data(stla>=min(opt.LATRNG) & stla<=max(opt.LATRNG));
                if(isempty(data)); continue; end
            end
            if(~isempty(opt.LONRNG))
                stlo=getheader(data,'stlo');
                data=data(stlo>=min(opt.LONRNG) & stlo<=max(opt.LONRNG));
                if(isempty(data)); continue; end
            end
            if(~isempty(opt.NETWORKS))
                knetwk=getheader(data,'knetwk');
                data=data(ismember(lower(knetwk),opt.NETWORKS));
                if(isempty(data)); continue; end
            end
            if(~isempty(opt.STATIONS))
                kstnm=getheader(data,'kstnm');
                data=data(ismember(lower(kstnm),opt.STATIONS));
                if(isempty(data)); continue; end
            end
            if(~isempty(opt.STREAMS))
                khole=getheader(data,'khole');
                data=data(ismember(lower(khole),opt.STREAMS));
                if(isempty(data)); continue; end
            end
            if(~isempty(opt.COMPONENTS))
                kcmpnm=getheader(data,'kcmpnm');
                data=data(ismember(lower(kcmpnm),opt.COMPONENTS));
                if(isempty(data)); continue; end
            end
        end
        
        % read in data
        data=readdata(data);
        
        % detail message
        if(verbose); disp(['PROCESSING: ' tsdir{i}{j}]); end
        
        % turn off checking
        oldseizmocheckstate=seizmocheck_state(false);
        oldcheckheaderstate=checkheader_state(false);
        
        try
            % process data for noise analysis
            if(any(steps==1)) % remove dead
                data=removedeadrecords(data);
                if(isempty(data)); continue; end
            end
            if(any(steps==2)) % remove short
                [b,e]=getheader(data,'b','e');
                data=data(...
                    e-b>opt.MINIMUMLENGTH*timediff(tsbgn,tsend,'utc'));
                if(isempty(data)); continue; end
            end
            if(any(steps==3)) % remove trend
                data=removetrend(data);
            end
            if(any(steps==4)) % taper
                data=taper(data,opt.TAPERWIDTH,...
                    [],opt.TAPERTYPE,opt.TAPEROPT);
            end
            if(any(steps==5)) % resample
                data=syncrates(data,opt.SAMPLERATE);
            end
            if(any(steps==6)) % remove pz
                if(~isempty(opt.PZDB)); data=getsacpz(data,opt.PZDB); end
                data=removesacpz(data,...
                    'units',opt.UNITS,'tl',opt.PZTAPERLIMITS);
                if(isempty(data)); continue; end
            end
            if(any(steps==7))
                % PLACEHOLDER -- CURRENTLY UNIMPLEMENTED
                %
                % Considering that this will "zero out" earthquakes based
                % on a catalog (globalcmt at this point).  That will
                % require lots of work to make it effective:
                % - quake magnitude vs distance
                % - blackout time vs distance & magnitude
                % - record-by-record find events within a day and figure
                %   out blackout time spans for that station
            end
            
            % HIDDEN STEP (required for 8+)
            % splits data into vertical and horizontal sets
            if(~isxc && any(steps>7))
                vdata=data(vertcmp(data));
                hdata=data(horzcmp(data));
                hvsplit=true;
                data=[]; % clearing data
                if(isempty(hdata) && isempty(vdata)); continue; end
            end
            
            % continue processing data for noise analysis
            if(any(steps==8)) % rotate horz to NE
                if(~isempty(hdata))
                    hdata=rotate(hdata,'to',0,'kcmpnm1','N','kcmpnm2','E');
                end
                if(isempty(hdata) && isempty(vdata)); continue; end
            end
            if(any(steps==9)) % td norm
                % have to rotate to sort horizontals if not done before
                if(~any(steps==8) && ~isempty(hdata))
                    hdata=rotate(hdata,'to',0,'kcmpnm1','N','kcmpnm2','E');
                end
                if(isempty(hdata) && isempty(vdata)); continue; end
                
                % normalization style
                switch lower(opt.TDSTYLE)
                    case '1bit'
                        if(~isempty(vdata))
                            vdata=solofun(vdata,@sign);
                        end
                        if(~isempty(hdata))
                            % orthogonal pair 1bit: x^2+y^2=1
                            weights=solofun(addrecords(...
                                solofun(hdata(1:2:end),@(x)x.^2),...
                                solofun(hdata(2:2:end),@(x)x.^2)),@sqrt);
                            hdata=dividerecords(hdata,...
                                weights([1:end; 1:end]));
                        end
                    case 'clip'
                        if(~isempty(vdata))
                            if(opt.TDRMS)
                                % use robust rms (better for spikes)
                                rms=getvaluefun(vdata,...
                                    @(x)sqrt(median(x.^2-median(x).^2)));
                                tdclip=rms*opt.TDCLIP;
                            else
                                tdclip=opt.TDCLIP;
                            end
                            vdata=clip(vdata,tdclip);
                        end
                        if(~isempty(hdata))
                            % orthogonal pair clipping
                            if(opt.TDRMS)
                                rms=getvaluefun(solofun(addrecords(...
                                    solofun(hdata(1:2:end),@(x)x.^2),...
                                    solofun(hdata(2:2:end),@(x)x.^2)),...
                                    @sqrt),@(x)sqrt(median(x.^2)));
                                tdclip=rms([1:end; 1:end])*opt.TDCLIP;
                            else
                                tdclip=opt.TDCLIP;
                            end
                            hdata=clip(hdata,tdclip);
                        end
                    case 'ram'
                        tdwb=opt.TDWEIGHTBAND;
                        if(~isempty(vdata))
                            delta=getheader(vdata(1),'delta');
                            weights=add(slidingabsmean(iirfilter(vdata,...
                                'bp','b','c',tdwb(1,:),'o',4,'p',2),...
                                ceil(1/(2*delta*min(tdwb(:))))),eps);
                            for a=2:size(tdwb,1)
                                weights=addrecords(weights,...
                                    add(slidingabsmean(iirfilter(vdata,...
                                    'bp','b','c',tdwb(a,:),'o',4,'p',2),...
                                    ceil(1/(2*delta*min(tdwb(:))))),eps));
                            end
                            vdata=dividerecords(vdata,weights);
                        end
                        if(~isempty(hdata))
                            weights=add(slidingabsmean(iirfilter(hdata,...
                                'bp','b','c',tdwb(1,:),'o',4,'p',2),...
                                ceil(1/(2*delta*min(tdwb(:))))),eps);
                            for a=2:size(tdwb,1)
                                weights=addrecords(weights,...
                                    add(slidingabsmean(iirfilter(hdata,...
                                    'bp','b','c',tdwb(a,:),'o',4,'p',2),...
                                    ceil(1/(2*delta*min(tdwb(:))))),eps));
                            end
                            weights=solofun(addrecords(...
                                solofun(weights(1:2:end),@(x)x.^2),...
                                solofun(weights(2:2:end),@(x)x.^2)),@sqrt);
                            hdata=dividerecords(hdata,...
                                weights([1:end; 1:end]));
                        end
                    otherwise
                        error('seizmo:noise_process:badInput',...
                            'Unknown TDSTYLE: %s',opt.TDSTYLE);
                end
            end
            if(any(steps==10)) % fd norm
                % have to rotate to sort horizontals if not done before
                if(~any(steps==8) && ~isempty(hdata))
                    hdata=rotate(hdata,'to',0,'kcmpnm1','N','kcmpnm2','E');
                end
                if(isempty(hdata) && isempty(vdata)); continue; end
                
                % normalization style
                switch lower(opt.FDSTYLE)
                    case '1bit'
                        if(~isempty(vdata))
                            vdata=dft(vdata);
                            vdata=solofun(vdata,@(x)[x(:,1).^0,x(:,2)]);
                            vdata=idft(vdata);
                        end
                        if(~isempty(hdata))
                            % orthogonal pair 1bit: x^2+y^2=1
                            hdata=dft(hdata,'rlim');
                            amph=rlim2amph(hdata);
                            amph=solofun(amph,...
                                @(x)x(:,[1:2:end; 1:2:end])+eps);
                            amph=solofun(addrecords(...
                                solofun(amph(1:2:end),@(x)x.^2),...
                                solofun(amph(2:2:end),@(x)x.^2)),@sqrt);
                            amph=changeheader(amph,'iftype','irlim');
                            hdata=dividerecords(hdata,...
                                amph([1:end; 1:end]));
                            hdata=idft(hdata);
                        end
                    case 'ram'
                        if(~isempty(vdata))
                            vdata=dft(vdata,'rlim');
                            vdata=whiten(vdata,opt.FDWIDTH);
                            vdata=idft(vdata);
                        end
                        if(~isempty(hdata))
                            % orthogonal pair ram: x^2+y^2=1
                            hdata=dft(hdata,'rlim');
                            amph=rlim2amph(hdata);
                            amph=slidingmean(amph,ceil(opt.FDWIDTH...
                                ./getheader(hdata,'delta')));
                            amph=solofun(amph,...
                                @(x)x(:,[1:2:end; 1:2:end])+eps);
                            amph=solofun(addrecords(...
                                solofun(amph(1:2:end),@(x)x.^2),...
                                solofun(amph(2:2:end),@(x)x.^2)),@sqrt);
                            amph=changeheader(amph,'iftype','irlim');
                            hdata=dividerecords(hdata,...
                                amph([1:end; 1:end]));
                            hdata=idft(hdata);
                        end
                    otherwise
                        error('seizmo:noise_process:badInput',...
                            'Unknown FDSTYLE: %s',opt.TDSTYLE);
                end
            end
            if(any(steps==11)) % xc
                if(numel(vdata)<2 && numel(hdata)<2); continue; end
                if(numel(vdata)>1)
                    delta=getheader(vdata(1),'delta');
                    vdata=interpolate(correlate(...
                        cut(vdata,'a','f','fill',true),...
                        'lags',(opt.XCMAXLAG+4*delta).*[-1 1]),...
                        1/delta,[],-opt.XCMAXLAG,opt.XCMAXLAG);
                    [vdata.path]=deal([indir fs yrdir{i} fs tsdir{i}{j}]);
                else
                    vdata=vdata([]);
                end
                if(numel(hdata)>1)
                    delta=getheader(hdata(1),'delta');
                    hdata=interpolate(correlate(...
                        cut(hdata,'a','f','fill',true),...
                        'lags',(opt.XCMAXLAG+4*delta).*[-1 1]),...
                        1/delta,[],-opt.XCMAXLAG,opt.XCMAXLAG);
                    [hdata.path]=deal([indir fs yrdir{i} fs tsdir{i}{j}]);
                else
                    hdata=hdata([]);
                end
            end
            if(any(steps==12)) % rotate xc
                % this removes ZZ correlations!
                if(isxc)
                    data=rotate_correlations(data);
                else
                    if(~isempty(hdata))
                        hdata=rotate_correlations(hdata);
                    end
                end
            end
            
            % write the data
            if(isxc || ~hvsplit)
                if(isempty(data)); continue; end
                writeseizmo(data,'path',...
                    [outdir fs yrdir{i} fs tsdir{i}{j} fs]);
            else
                if(~isempty(vdata))
                    writeseizmo(vdata,'path',...
                        [outdir fs yrdir{i} fs tsdir{i}{j} fs]);
                end
                if(~isempty(hdata))
                    writeseizmo(hdata,'path',...
                        [outdir fs yrdir{i} fs tsdir{i}{j} fs]);
                end
            end
            
            % toggle checking back
            seizmocheck_state(oldseizmocheckstate);
            checkheader_state(oldcheckheaderstate);
        catch
            % toggle checking back
            seizmocheck_state(oldseizmocheckstate);
            checkheader_state(oldcheckheaderstate);
            
            % parallel processing takedown & fix verbosity
            %matlabpool close; % PARALLEL
            seizmoverbose(verbose);
            
            % rethrow error
            error(lasterror);
        end
    end
end

% parallel processing takedown & fix verbosity
%matlabpool close; % PARALLEL
seizmoverbose(verbose);

end


function [opt]=noise_process_parameters(varargin)
% parses/checks noise_process pv pairs

% defaults
varargin=[{'minlen' 70 'tw' 1 'tt' [] 'topt' [] 'sr' 1 ...
    'pzdb' [] 'units' 'disp' 'pztl' [.004 .008] ...
    'tds' 'ram' 'tdrms' true 'tdclip' 1 'tdfb' [1/15 1/3;.01 1/15] ...
    'fds' 'ram' 'fdw' .002 'lag' 4000 ...
    'ts' [] 'te' [] 'lat' [] 'lon' [] ...
    'net' [] 'sta' [] 'str' [] 'cmp' [] 'file' [] 'q' false} varargin];

% get user input
for i=1:2:numel(varargin)
    switch lower(varargin{i})
        case {'minimumlength' 'ml' 'minlen' 'mlen' 'minl' 'minlength'}
            if(isempty(varargin{i+1})); continue; end
            opt.MINIMUMLENGTH=varargin{i+1};
        case {'taperwidth' 'tw' 'taperw' 'tapw' 'twidth'}
            if(isempty(varargin{i+1})); continue; end
            opt.TAPERWIDTH=varargin{i+1};
        case {'tapertype' 'tt' 'tapert' 'tapt' 'ttype'}
            opt.TAPERTYPE=varargin{i+1};
        case {'taperopt' 'topt' 'tapero' 'tapo' 'tapopt' 'taperoption'}
            opt.TAPEROPT=varargin{i+1};
        case {'samplerate' 'sr' 'srate'}
            if(isempty(varargin{i+1})); continue; end
            opt.SAMPLERATE=varargin{i+1};
        case {'pzdb' 'db' 'pz'}
            opt.PZDB=varargin{i+1};
        case {'units' 'to' 'u' 'unit' 'un'}
            if(isempty(varargin{i+1})); continue; end
            opt.UNITS=varargin{i+1};
        case {'pztaperlimits' 'pztl' 'tl' 'taperlim' 'tlim' 'taplim'}
            if(isempty(varargin{i+1})); continue; end
            opt.PZTAPERLIMITS=varargin{i+1};
        case {'tdstyle' 'td' 'tds'}
            if(isempty(varargin{i+1})); continue; end
            opt.TDSTYLE=varargin{i+1};
        case {'tdrms' 'rms'}
            if(isempty(varargin{i+1})); continue; end
            opt.TDRMS=varargin{i+1};
        case {'tdclip' 'clip'}
            if(isempty(varargin{i+1})); continue; end
            opt.TDCLIP=varargin{i+1};
        case {'tdweightband' 'tdfreqband' 'tdwb' 'tdfb'}
            if(isempty(varargin{i+1})); continue; end
            opt.TDWEIGHTBAND=varargin{i+1};
        case {'fdstyle' 'fd' 'fds'}
            if(isempty(varargin{i+1})); continue; end
            opt.FDSTYLE=varargin{i+1};
        case {'fdwidth' 'fdw'}
            if(isempty(varargin{i+1})); continue; end
            opt.FDWIDTH=varargin{i+1};
        case {'xcmaxlag' 'xcmax' 'xclag' 'maxlag' 'lag'}
            if(isempty(varargin{i+1})); continue; end
            opt.XCMAXLAG=varargin{i+1};
        case {'ts' 'tstart' 'timestart'}
            opt.TIMESTART=varargin{i+1};
        case {'te' 'tend' 'timeend'}
            opt.TIMEEND=varargin{i+1};
        case {'lat' 'la' 'lar' 'latr' 'larng' 'latitude' 'latrng'}
            opt.LATRNG=varargin{i+1};
        case {'lon' 'lo' 'lor' 'lonr' 'lorng' 'longitude' 'lonrng'}
            opt.LONRNG=varargin{i+1};
        case {'knetwk' 'n' 'net' 'netwk' 'network' 'nets' 'networks'}
            opt.NETWORKS=varargin{i+1};
        case {'kstnm' 'st' 'sta' 'stn' 'stns' 'stations' 'station'}
            opt.STATIONS=varargin{i+1};
        case {'khole' 'hole' 'holes' 'str' 'strs' 'stream' 'streams'}
            opt.STREAMS=varargin{i+1};
        case {'kcmpnm' 'cmpnm' 'cmp' 'cmps' 'component' 'components'}
            opt.COMPONENTS=varargin{i+1};
        case {'f' 'file' 'filename' 'files' 'filenames'}
            opt.FILENAMES=varargin{i+1};
        case {'q' 'qw' 'quiet' 'qwrite' 'quietwrite'}
            if(isempty(varargin{i+1})); continue; end
            opt.QUIETWRITE=varargin{i+1};
        otherwise
            error('seizmo:noise_process:badInput',...
                'Unknown Option: %s !',varargin{i});
    end
end

% fix string options to be cellstr vectors
if(ischar(opt.NETWORKS)); opt.NETWORKS=cellstr(opt.NETWORKS); end
if(ischar(opt.STATIONS)); opt.STATIONS=cellstr(opt.STATIONS); end
if(ischar(opt.STREAMS)); opt.STREAMS=cellstr(opt.STREAMS); end
if(ischar(opt.COMPONENTS)); opt.COMPONENTS=cellstr(opt.COMPONENTS); end
if(ischar(opt.FILENAMES)); opt.FILENAMES=cellstr(opt.FILENAMES); end
if(iscellstr(opt.NETWORKS))
    opt.NETWORKS=unique(lower(opt.NETWORKS(:)));
end
if(iscellstr(opt.STATIONS))
    opt.STATIONS=unique(lower(opt.STATIONS(:)));
end
if(iscellstr(opt.STREAMS)); opt.STREAMS=unique(lower(opt.STREAMS(:))); end
if(iscellstr(opt.COMPONENTS))
    opt.COMPONENTS=unique(lower(opt.COMPONENTS(:)));
end
if(iscellstr(opt.FILENAMES)); opt.FILENAMES=unique(opt.FILENAMES(:)); end

% check options
szs=size(opt.TIMESTART);
sze=size(opt.TIMEEND);
szp=size(opt.PZTAPERLIMITS);
if(~isscalar(opt.MINIMUMLENGTH) || ~isreal(opt.MINIMUMLENGTH) ...
        || opt.MINIMUMLENGTH<0 || opt.MINIMUMLENGTH>100)
    error('seizmo:noise_process:badInput',...
        'MINIMUMLENGTH must be a scalar within 0 & 100 (%%)!');
elseif(~isscalar(opt.TAPERWIDTH) || ~isreal(opt.TAPERWIDTH) ...
        || opt.TAPERWIDTH<0 || opt.TAPERWIDTH>100)
    error('seizmo:noise_process:badInput',...
        'TAPERWIDTH must be a scalar within 0 & 100 (%%)!');
elseif(~isempty(opt.TAPERTYPE) && (~ischar(opt.TAPERTYPE) ...
        || ~isvector(opt.TAPERTYPE) || size(opt.TAPERTYPE,1)~=1))
    error('seizmo:noise_process:badInput',...
        'TAPERTYPE should be a string indicating a valid taper!');
elseif(~isempty(opt.TAPEROPT) && (~isscalar(opt.TAPEROPT) ...
        || ~isreal(opt.TAPEROPT)))
    error('seizmo:noise_process:badInput',...
        'TAPEROPT should be a real-valued scalar!');
elseif(~isscalar(opt.SAMPLERATE) || ~isreal(opt.SAMPLERATE) ...
        || opt.SAMPLERATE<=0)
    error('seizmo:noise_process:badInput',...
        'SAMPLERATE should be a positive real-valued scalar!');
elseif(~isempty(opt.PZDB) && ~isstruct(opt.PZDB) && (~ischar(opt.PZDB) ...
        || ~isvector(opt.PZDB) || size(opt.PZDB,1)~=1))
    error('seizmo:noise_process:badInput',...
        'PZDB should be either a struct or a string!');
elseif(~ischar(opt.UNITS) || ~isvector(opt.UNITS) || size(opt.UNITS,1)~=1)
    error('seizmo:noise_process:badInput',...
        'UNITS should be a string!');
elseif(~isempty(opt.PZTAPERLIMITS) && (numel(szp)>2 || szp(1)~=1 ...
        || all(szp(2)~=[2 4]) || ~isnumeric(opt.PZTAPERLIMITS) ...
        || ~isreal(opt.PZTAPERLIMITS) || any(opt.PZTAPERLIMITS<0)))
    error('seizmo:noise_process:badInput',...
        'PZTAPERLIMITS should be a [LOWSTOP LOWPASS] or [LS LP HP HS]!');
elseif(~ischar(opt.TDSTYLE) || ~isvector(opt.TDSTYLE) ...
        || size(opt.TDSTYLE,1)~=1)
    error('seizmo:noise_process:badInput',...
        'TDSTYLE should be a string!');
elseif(~isscalar(opt.TDRMS) || ~islogical(opt.TDRMS))
    error('seizmo:noise_process:badInput',...
        'TDRMS should be true or false!');
elseif(~isscalar(opt.TDCLIP) || ~isreal(opt.TDCLIP))
    error('seizmo:noise_process:badInput',...
        'TDCLIP should be a real-valued scalar!');
elseif(~isnumeric(opt.TDWEIGHTBAND) || ~isreal(opt.TDWEIGHTBAND) ...
        || size(opt.TDWEIGHTBAND,2)~=2 ...
        || numel(size(opt.TDWEIGHTBAND))~=2 || any(opt.TDWEIGHTBAND(:)<0))
    error('seizmo:noise_process:badInput',...
        'TDWEIGHTBAND should be [LOW HIGH] in Hz!');
elseif(~ischar(opt.FDSTYLE) || ~isvector(opt.FDSTYLE) ...
        || size(opt.FDSTYLE,1)~=1)
    error('seizmo:noise_process:badInput',...
        'FDSTYLE should be a string!');
elseif(~isscalar(opt.FDWIDTH) || ~isreal(opt.FDWIDTH) || opt.FDWIDTH<=0)
    error('seizmo:noise_process:badInput',...
        'FDWIDTH should be a positive real-valued scalar!');
elseif(~isscalar(opt.XCMAXLAG) || ~isreal(opt.XCMAXLAG) ...
        || opt.XCMAXLAG<=0)
    error('seizmo:noise_process:badInput',...
        'XCMAXLAG should be a positive real-valued scalar in seconds!');
elseif(~isscalar(opt.QUIETWRITE) || ~islogical(opt.QUIETWRITE))
    error('seizmo:noise_process:badInput',...
        'QUIETWRITE flag must be a scalar logical!');
elseif(~isempty(opt.TIMESTART) && (numel(szs)>2 || szs(1)~=1 ...
        || all(szs(2)~=[2 3 5 6]) || ~isnumeric(opt.TIMESTART) ...
        || ~isreal(opt.TIMESTART)))
    error('seizmo:noise_process:badInput',...
        'TIMESTART must be a recognized date-time vector!');
elseif(~isempty(opt.TIMEEND) && (numel(sze)>2 || sze(1)~=1 ...
        || all(sze(2)~=[2 3 5 6]) || ~isnumeric(opt.TIMEEND) ...
        || ~isreal(opt.TIMEEND)))
    error('seizmo:noise_process:badInput',...
        'TIMEEND must be a recognized date-time vector!');
elseif(~isempty(opt.LATRNG) && (~isnumeric(opt.LATRNG) ...
        || ~isreal(opt.LATRNG) || numel(opt.LATRNG)~=2 ...
        || size(opt.LATRNG,2)~=2 || numel(size(opt.LATRNG))~=2))
    error('seizmo:noise_process:badInput',...
        'LATRNG must be a 2 element numeric vector as [LOW HIGH]!');
elseif(~isempty(opt.LONRNG) && (~isnumeric(opt.LONRNG) ...
        || ~isreal(opt.LONRNG) || numel(opt.LONRNG)~=2 ...
        || size(opt.LONRNG,2)~=2 || numel(size(opt.LONRNG))~=2))
    error('seizmo:noise_process:badInput',...
        'LONRNG must be a 2 element numeric vector as [LOW HIGH]!');
elseif(~isempty(opt.NETWORKS) && (~iscellstr(opt.NETWORKS)))
    error('seizmo:noise_process:badInput',...
        'NETWORKS must be a string list of allowed network codes!');
elseif(~isempty(opt.STATIONS) && (~iscellstr(opt.STATIONS)))
    error('seizmo:noise_process:badInput',...
        'STATIONS must be a string list of allowed station codes!');
elseif(~isempty(opt.STREAMS) && (~iscellstr(opt.STREAMS)))
    error('seizmo:noise_process:badInput',...
        'STREAMS must be a string list of allowed stream codes!');
elseif(~isempty(opt.COMPONENTS) && (~iscellstr(opt.COMPONENTS)))
    error('seizmo:noise_process:badInput',...
        'COMPONENTS must be a string list of allowed component codes!');
elseif(~isempty(opt.FILENAMES) && (~iscellstr(opt.FILENAMES)))
    error('seizmo:noise_process:badInput',...
        'FILENAMES must be a string list of allowed files!');
end

% percent to fraction
opt.MINIMUMLENGTH=opt.MINIMUMLENGTH/100;
opt.TAPERWIDTH=opt.TAPERWIDTH/100;

end

