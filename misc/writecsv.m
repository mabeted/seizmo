function []=writecsv(file,lines,o)
%WRITECSV    Write out .csv formatted file from a structure
%
%    Usage:    writecsv(file,struct)
%              writecsv(file,struct,overwrite)
%
%    Description: WRITECSV(FILE,STRUCT) writes a comma-separated values
%     (CSV) text file FILE using the struct array STRUCT.  STRUCT is
%     expected to be a single-level structure with all character string
%     values.  If FILE is an empty string a graphical file creation menu is
%     presented.
%
%     WRITECSV(FILE,STRUCT,OVERWRITE) quietly overwrites pre-existing CSV
%     files without confirmation when OVERWRITE is set to TRUE.  By default
%     OVERWRITE is FALSE.  OVERWRITE is ignored in the graphical file
%     creation menu.
%
%    Notes:
%     - Look out for text entries with commas or line terminators.  They
%       will not be read back in correctly!
%
%    Examples:
%     Read a SOD (Standing Order for Data) generated event csv file, change
%     the locations a bit, and write out the updated version:
%      events=readcsv('events.csv')
%      tmp={events.latitude};
%      [events.latitude]=deal(events.longitude);
%      [events.longitude]=deal(tmp{:});
%      writecsv('events_flip.csv',events)
%
%     Make your own .csv:
%      a=struct('yo',{'woah' 'dude!'},'another',{'awe' 'some'});
%      writecsv('easy.csv',a)
%
%    See also: READCSV, CSVREAD, CSVWRITE

%     Version History:
%        Sep. 16, 2009 - initial version
%        Sep. 22, 2009 - fixed dir check bug, skip confirmation option
%        Jan. 26, 2010 - add graphical selection
%        Feb.  5, 2010 - add check for overwrite flag
%        Feb. 11, 2011 - mass nargchk fix, use fprintf
%
%     Written by Garrett Euler (ggeuler at wustl dot edu)
%     Last Updated Feb. 11, 2011 at 15:05 GMT

% todo:

% check nargin
error(nargchk(2,3,nargin));

% default overwrite to false
if(nargin==2 || isempty(o)); o=false; end
if(~isscalar(o) || ~islogical(o))
    error('seizmo:writecsv:badInput',...
        'OVERWRITE flag must be a scalar logical!');
end

% check structure
if(~isstruct(lines))
    error('seizmo:writecsv:badInput',...
        'STRUCT must be a struct array!');
end

% graphical selection
if(isempty(file))
    [file,path]=uiputfile(...
        {'*.csv;*.CSV' 'CSV Files (*.csv,*.CSV)';
        '*.*' 'All Files (*.*)'},...
        'Save CSV File as');
    if(isequal(0,file))
        error('seizmo:writecsv:noFileSelected','No output file selected!');
    end
    file=strcat(path,filesep,file);
else
    % check file
    if(~ischar(file) || ~isvector(file))
        error('seizmo:writecsv:fileNotString',...
            'FILE must be a string!');
    end
    if(exist(file,'file'))
        if(exist(file,'dir'))
            error('seizmo:writecsv:dirConflict',...
                'CSV File: %s\nIs A Directory!',file);
        end
        if(~o)
            fprintf('CSV File: %s\nFile Exists!\n',file);
            reply=input('Overwrite? Y/N [N]: ','s');
            if(isempty(reply) || ~strncmpi(reply,'y',1))
                disp('Not overwriting!');
                return;
            end
            disp('Overwriting!');
        end
    end
end

% get the field names
f=fieldnames(lines);
nf=numel(f);

% build the cellstr array
nlines=numel(lines)+1;
tmp(1:2*nf,1:nlines)={', '};
tmp(1:2:2*nf,1)=f;
for i=1:nf
    tmp(2*i-1,2:end)={lines.(f{i})};
end

% add line terminators
tmp(2*nf,:)={sprintf('\n')};

% check is cellstr
if(~iscellstr(tmp))
    error('seizmo:writecsv:badInput',...
        'All values in STRUCT must be char!');
end

% build the char vector
for i=1:numel(tmp); tmp(i)={tmp{i}(:)}; end
tmp=char(tmp);

% open file for writing
fid=fopen(file,'w');

% check if file is openable
if(fid<0)
    error('seizmo:writecsv:cannotOpenFile',...
        'CSV File: %s\nNot Openable!',file);
end

% write to file
cnt=fwrite(fid,tmp,'char');

% check count
if(cnt~=numel(tmp))
    error('seizmo:writecsv:writeFailed',...
        'CSV File: %s\nCould not write (some) text to file!',file);
end

% close file
fclose(fid);

end
