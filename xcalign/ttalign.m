function [m,Gg]=ttalign(lag,lagw,abstt,absw,absidx)
%TTALIGN    Solves for Relative/Absolute Travel Times via Weighted Least Sq
%
%    Usage:    [m,Gg]=ttalign(lag)
%              [m,Gg]=ttalign(lag,lagw)
%              [m,Gg]=ttalign(lag,lagw,abstt,absw,absidx)
%
%    Description: [M,Gg]=TTALIGN(LAG) solves the matrix of relative lag
%     times LAG in a least-squares sense for the optimal relative arrival
%     times M (zero-centered).  Secondary output Gg is the generalized
%     inverse of G in the equation G*M=LAG (so M=Gg*LAG).  This is an
%     overdetermined problem so Gg=(G.'*G)\G.'.
%
%     [M,Gg]=TTALIGN(LAG,LAGW) assigns weights LAGW to the corresponding
%     elements in LAG when solving for M.  Higher weights forces the
%     solution to respect the corresponding lags while lower weights can be
%     used to dampen the effect of outliers.  One might use signal to noise
%     ratio and/or peak cross correlation values for weighting.
%
%     [M,Gg]=TTALIGN(LAG,LAGW,ABSTT,ABSW,ABSIDX) ties the cross correlation
%     relative lag times to some absolute travel times in ABSTT.  The
%     travel times may be weighted using ABSW.  ABSIDX indicates which
%     arrivals correspond to ABSTT.  This is useful for shifting relative
%     arrival times to align with absolute arrival times in a least squares
%     sense.
%
%    Notes:
%     - If using cross correlation values for weighting, it is better to
%       first convert them to z-values (see FISHER).  This gives a better
%       approximation to a normal distribution that will enhance weights.
%
%    Examples:
%     A simple case (synthetic arrivals at
%     1 to 10 sec hidden in some noise):
%      arr=1:10;
%      lg=arr(ones(10,1),:)-arr(ones(10,1),:)'+2*rand(10)-1;
%      ttalign(lg)
%
%     Get the covariance of the arrivals assuming the variance of the data
%     is the square of 1/2 the sample interval of records (sampled at 5Hz
%     here) and that there is no data covariance:
%      [m,Gg]=ttalign(lags);
%      covd=((0.2/2)^2)*eye(numel(lg));
%      covm=Gg*covd*Gg.';
%
%     Tie cross correlation results to some absolute time picks:
%      ttalign(lags,[],[725.5 801.1],1,[22 30])
%
%    See also: WLINEM, TTSTDERR, TTPOLAR, TTREFINE, TTSOLVE

%     Version History:
%        Mar.  2, 2010 - initial version (from dtwalign)
%        Mar. 11, 2010 - renamed to TTALIGN from TTSOLVE
%        Mar. 22, 2010 - huge bugfix (incorrect sign for output relative
%                        times and completely wrong times for absolute
%                        times)
%        Sep. 13, 2010 - nargchk fix
%        Feb. 11, 2011 - drop inv calls, minor doc update
%
%     Written by Garrett Euler (ggeuler at wustl dot edu)
%     Last Updated Feb. 11, 2011 at 01:05 GMT

% todo:

% check nargin
error(nargchk(1,5,nargin));

% check lag
[lag,nr,len,i,j]=m2v(lag,'LAG');

% default lagw
if(nargin<2 || isempty(lagw)); lagw=ones(size(lag)); end

% check lagw
[lagw,nr2]=m2v(lagw,'LAGW');
if(nr~=nr2)
    error('seizmo:ttalign:badInput',...
        'LAG & LAGW are inconsistent in size!');
end

% are we just using relative arrivals?
if(nargin<3)
    % BUILDING KERNEL MATRIX (G)
    totlen=len+1;
    G=sparse([1:len 1:len],[j i],...
        [-ones(1,len) ones(1,len)],totlen,nr,2*len+nr);
    G(totlen,:)=1;
    
    % BUILDING THE WEIGHTING MATRIX (W)
    W=sparse(1:totlen,1:totlen,[lagw(:); 1],totlen,totlen);
    
    % GENERALIZED INVERSE (Gg) (OVERDETERMINED CASE)
    Gg=full((G.'*W*G)\G.'*W);
    
    % FINDING LEAST SQUARES RELATIVE ARRIVALS (m)
    m=Gg*[lag(:); 0];
else % some absolute timing info also
    % check abstt/absw/absidx
    if(nargin==3 || isempty(absw)); absw=1; end
    if(isscalar(absw)); absw=absw(ones(size(abstt))); end
    if(~isreal(abstt) || ~isreal(absw) || ~isreal(absidx))
        error('seizmo:ttalign:badInput',...
            'ABSTT, ABSW, ABSIDX must be real-valued arrays!');
    elseif(~isequal(numel(abstt),numel(absw),numel(absidx)))
        error('seizmo:ttalign:badInput',...
            'ABSTT, ABSW, ABSIDX must be equal-sized arrays!');
    end
    
    % BUILDING KERNEL MATRIX (G)
    alen=numel(absidx); totlen=alen+len;
    G=sparse([1:len 1:len len+1:totlen],[j; i; absidx(:)]',...
        [-ones(1,len) ones(1,len) ones(1,alen)],totlen,nr,2*len+alen);
    
    % BUILDING THE WEIGHTING MATRIX (W)
    W=sparse(1:totlen,1:totlen,...
        [lagw(:); absw(:)],totlen,totlen);
    
    % GENERALIZED INVERSE (Gg) (OVERDETERMINED CASE)
    Gg=full((G.'*W*G)\G.'*W);
    
    % FINDING LEAST SQUARES ABSOLUTE ARRIVALS (m)
    m=Gg*[lag(:); abstt(:)];
end

end

function [x,nr,len,i,j]=m2v(x,str)

% check lag
if(~isreal(x))
    error('seizmo:ttalign:badInput',...
        '%s option must be a real-valued array!',str);
end

% allow either vector or matrix form
if(isvector(x))
    len=numel(x);                         % NUMBER OF LAGS
    nr=ceil(sqrt(2*len));                 % NUMBER OF RECORDS (FAST)
    %nr=round(max(roots([1 -1 -2*len]))); % NUMBER OF RECORDS (OLD)
    
    % assure length is ok
    if((nr^2-nr)/2~=len)
        error('seizmo:ttalign:badInput',...
            '%s option is not a properly lengthed vector!',str);
    end
    
    % matrix subscripts
    [i,j]=ind2sub([nr nr],find(tril(true(nr),-1)));
else % matrix/grid form
    % grid size
    xs=size(x); nr=xs(1); len=(nr^2-nr)/2;
    
    % check that grid is square & 2D
    if(numel(xs)>2 || xs(1)~=xs(2))
        error('seizmo:ttalign:badInput',...
            '%s option is not a 2D square matrix!',str);
    end
    
    % grid to vector
    li=tril(true(xs(1)),-1);
    x=x(li);
    
    % matrix subscripts
    [i,j]=ind2sub(xs,find(li));
end

end
