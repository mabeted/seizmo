function [varargout]=getlgc(data,varargin)
%GETLGC    Get logical string from SEIZMO logical header field
%
%    Usage:    cellstr=getlgc(data,'field')
%              [cellstr1,...,cellstrN]=getlgc(data,'field1',...,'fieldN')
%
%    Description: GETLGC(DATA,FIELD) returns a cellstring array containing
%     'true' 'false' or 'NaN' corresponding to values of the logical field
%     FIELD in the SEIZMO structure DATA.  This provides a more consistent
%     logic framework than the output of GETHEADER for working with
%     multiple datafile versions.
%
%     GETLGC(DATA,FIELD1,...,FIELDN) returns a cellstring array for each
%     field supplied.
%    
%    Notes:
%     - Numeric header fields not defined to be logical can be used with 
%       GETLGC as if they were logical fields.  This gives the user the 
%       ability to have more logical fields if needed.  Character fields 
%       are NOT able to be treated as logical fields.
%     - Nonexistant header fields and undefined/invalid logical values
%       return 'NaN'.
%
%    Examples:
%     To check if all records are evenly spaced:
%      if(all(strcmp(getlgc(data,'leven'),'true'))) 
%          disp('evenly spaced data')
%      end
%
%     Treat field RESP0 as a logical field:
%      my_lgc=getlgc(data,'resp0')
%
%    See also: GETHEADER, GETENUMID, GETENUMDESC

%     Version History:
%        Feb. 12, 2008 - initial version
%        Feb. 23, 2008 - complete rewrite - whole words now
%        Feb. 28, 2008 - minor code cleaning
%        Mar.  4, 2008 - minor doc update
%        Apr. 18, 2008 - fix for r14sp1 (fix assign to null)
%        June 12, 2008 - doc update
%        June 13, 2008 - sorted out undefined and unknown values/fields
%        Sep. 28, 2008 - output cleanup
%        Oct. 17, 2008 - added VINFO support
%        Nov. 16, 2008 - history fix, rename from GLGC to GETLGC,
%                        doc update, code cleaning
%        Apr. 23, 2009 - move usage up
%        Sep. 12, 2009 - minor doc update
%        Oct.  6, 2009 - change special output to work with CHANGEHEADER
%        Jan. 29, 2010 - elimate extra VERSIONINFO call
%        Aug. 21, 2010 - all unknown fields/values return 'NaN', doc update
%
%     Written by Garrett Euler (ggeuler at wustl dot edu)
%     Last Updated Aug. 21, 2010 at 00:25 GMT

% todo:

% require at least two inputs
if(nargin<2)
    error('seizmo:getlgc:notEnoughInputs',...
        'Not enough input arguments.')
end

% preallocate output
varnargin=length(varargin);
nvarargout=cell(1,varnargin);
varargout=nvarargout;
[varargout{:}]=deal(cell(numel(data),1));

% get header info
[nvarargout{:}]=getheader(data,varargin{:});

% pull header setup
global SEIZMO
h=SEIZMO.VERSIONINFO.H;
idx=SEIZMO.VERSIONINFO.IDX;

% loop over versions
for i=1:numel(h)
    % indexing of data with this header version
    ind=find(idx==i);
    
    % loop over fields
    for j=1:numel(varargin)
        % check for cell output (char field)
        if(iscell(nvarargout{j}(ind)))
            error('seizmo:getlgc:badField',...
                'String fields are not supported!');
        end
        
        % compare
        tru=nvarargout{j}(ind)==h(i).true;
        fals=nvarargout{j}(ind)==h(i).false;
        bad=~(tru | fals);
        
        % assign logic words
        if(any(tru))
            varargout{j}(ind(tru))={'true'};
        end
        if(any(fals))
            varargout{j}(ind(fals))={'false'};
        end
        if(any(bad))
            varargout{j}(ind(bad))={'NaN'};
        end
    end
end

end
