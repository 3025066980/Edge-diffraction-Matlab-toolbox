function [tfdirect,tfgeom,tfdiff,timingdata,EDinputdatahash] = EDmakefirstordertfs(firstorderpathdata,...
    frequencies,Rstart,difforder,envdata,Sinputdata,receivers,edgedata,EDversionnumber,showtext)
% EDmakefirstordertfs calculates the direct sound, specular reflection, and
% first-order diffraction.
%
% Input parameters:
%   firstorderpathdata      Struct generated by EDfindconvexGApaths
%   frequencies
%   Rstart
%   difforder  
%   envdata                 Input struct; field .cair is used here
%   Sinputdata                 Struct with the fields
%   .coordinates            [nsources,3]
%   .doaddsources           0 or 1
%   .sourceamplitudes       [nsources,nfrequencies]: multiplication factor
%   receivers               Matrix, [nreceivers,3]
%   edgedata                Struct generated by EDfindedgedata
%   EDversionnumber 
%   showtext                (optional)
% 
% Output parameters:
%   tfdirect,tfgeom,tfdiff  Matrices, size [nfrequencies,nreceivers,nsources]
%                           (if doaddsources = 0) or [nfrequencies,nreceivers]
%                           (if doaddsources = 1)
%   timingdata              Vector, [1,3], containing times for the direct
%                           sound, spec. reflections, and first-order diffraction
%                           component generations
%   EDinputdatahash
%   
% Uses functions EDcoordtrans2, EDwedge1st_fd from EDtoolbox
% Uses function DataHash form Matlab Central
% 
% Peter Svensson 12 Feb 2018 (peter.svensson@ntnu.no)
%
% [tfdirect,tfgeom,tfdiff,timingdata,EDinputdatahash] = EDmakefirstordertfs(firstorderpathdata,...
%     frequencies,Rstart,difforder,envdata,Sinputdata,receivers,edgedata,EDversionnumber,showtext)

% 12 Jan. 2018 First complete version. Much simplified version of the
%                           previous ESIE2maketfs. Edgehits not handled
%                           yet.
% 15 Jan. 2018 Took the direct sound and spec refl amplitude 
%              (1, 0.5, 0.25) into account)
% 17 Jan. 2018 Had forgotten the Rstart factor for the direct sound and
% specular reflection.
% 17 Jan. 2018 Took the input parameter difforder into account
% 17 Jan 2018 Added showtext as input parameter. Fixed a bug which gave the
% wrong specular reflection amplitude.
% 18 Jan 2018 Changed input parameter to the Sinputdata struct, to also get
% the .sourceamplitudes field. Implemented the sourceamplitudes scale
% factor.
% 31 Jan 2018 Corrected the handling of sourceamplitudes (the frequency
% dependence was not handled before).
% 8 Feb 2018 Introduced the EDinputdatastruct. Changed input parameter from
% controlparameters to three of its fields.
% 12 Feb 2018 Adapted to a change in the EDwedge1st_fd (new output
% parameter).

if nargin < 10
   showtext = 0; 
end

EDinputdatastruct = struct('firstorderpathdata',firstorderpathdata,'edgedata',edgedata,...
    'frequencies',frequencies,'Rstart',Rstart,'difforder',difforder,'envdata',envdata,'Sinputdata',Sinputdata,...
    'receivers',receivers,'EDversionnumber',EDversionnumber);
EDinputdatahash = DataHash(EDinputdatastruct);

timingdata = zeros(1,3);

nfrequencies = length(frequencies);
nreceivers = size(receivers,1);
nsources = size(Sinputdata.coordinates,1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Direct sound

if showtext >= 2
   disp(['      Generating direct sound components']) 
end
t00 = clock;

if Sinputdata.doaddsources == 1
    tfdirect = zeros(nfrequencies,nreceivers);
else
    tfdirect = zeros(nfrequencies,nreceivers,nsources);
end

kvec = 2*pi*frequencies(:)/envdata.cair;

% alldists will be a matrix of size [nreceivers,nsources]

if firstorderpathdata.ncomponents(1) > 0
    ncomponents = size(firstorderpathdata.directsoundlist(:,1),1);

    distvecs = Sinputdata.coordinates(firstorderpathdata.directsoundlist(:,1),:) - ...
        receivers(firstorderpathdata.directsoundlist(:,2),:);

    if ncomponents == 1
       alldists = norm(distvecs);
    else
        alldists = sqrt( sum(distvecs.^2,2) ); 
    end
    
    maxrecnumber = max( firstorderpathdata.directsoundlist(:,2) );   

    if ncomponents > nfrequencies && Sinputdata.doaddsources == 1
        for ii = 1:nfrequencies   
           alltfs = exp(-1i*kvec(ii)*(alldists-Rstart))./alldists...
               .*firstorderpathdata.directsoundlist(:,3).*Sinputdata.sourceamplitudes( firstorderpathdata.directsoundlist(:,1),ii );
%            if Sinputdata.doaddsources == 1
               tfdirect(ii,1:maxrecnumber) = accumarray(firstorderpathdata.directsoundlist(:,2),alltfs);
%            else
%               tfdirect(ii,firstorderpathdata.directsoundlist(:,2),firstorderpathdata.directsoundlist(:,1)) = alltfs;
%            end

        end
    else
       for ii = 1:ncomponents 
            if nfrequencies > 1
                alltfs = exp(-1i*kvec*(alldists(ii)-Rstart))./alldists(ii)...
                    .*firstorderpathdata.directsoundlist(ii,3).*(Sinputdata.sourceamplitudes( firstorderpathdata.directsoundlist(ii,1),: ).');
            else
                alltfs = exp(-1i*kvec*(alldists(ii)-Rstart))./alldists(ii)...
                    .*firstorderpathdata.directsoundlist(ii,3).*(Sinputdata.sourceamplitudes( firstorderpathdata.directsoundlist(ii,1),: ));                
            end            
           if Sinputdata.doaddsources == 1
              tfdirect(:,firstorderpathdata.directsoundlist(ii,2)) = ...
                  tfdirect(:,firstorderpathdata.directsoundlist(ii,2)) + alltfs;
           else
               
              tfdirect(:,firstorderpathdata.directsoundlist(ii,2),firstorderpathdata.directsoundlist(ii,1)) = alltfs;
           end
       end
    end
end

timingdata(1) = etime(clock,t00);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Specular reflections

if showtext >= 2
   disp(['      Generating specular reflection components']) 
end

t00 = clock;

if Sinputdata.doaddsources == 1
    tfgeom = zeros(nfrequencies,nreceivers);
else
    tfgeom = zeros(nfrequencies,nreceivers,nsources);
end

if firstorderpathdata.ncomponents(2) > 0

    ncomponents = size(firstorderpathdata.specrefllist(:,1),1);

    distvecs = firstorderpathdata.specreflIScoords - ...
        receivers(firstorderpathdata.specrefllist(:,2),:);

    if ncomponents == 1
       alldists = norm(distvecs);
    else
        alldists = sqrt( sum(distvecs.^2,2) );
    end

    maxrecnumber = max( firstorderpathdata.specrefllist(:,2) );

    if ncomponents > nfrequencies && Sinputdata.doaddsources == 1
        for ii = 1:nfrequencies    
%             if nfrequencies > 1
%                 alltfs = exp(-1i*kvec(ii)*(alldists-Rstart))./alldists...
%                     .*firstorderpathdata.specrefllist(:,3).*(Sinputdata.sourceamplitudes( firstorderpathdata.specrefllist(:,1),ii ).');
%             else
                alltfs = exp(-1i*kvec(ii)*(alldists-Rstart))./alldists...
                    .*firstorderpathdata.specrefllist(:,3).*(Sinputdata.sourceamplitudes( firstorderpathdata.specrefllist(:,1),ii ));                
%             end
%             if Sinputdata.doaddsources == 1
                tfgeom(ii,1:maxrecnumber) = accumarray(firstorderpathdata.specrefllist(:,2),alltfs);
%             else
%                 tfgeom(ii,firstorderpathdata.specrefllist(:,2),firstorderpathdata.specrefllist(:,1)) = alltfs;
%             end
        end
    else
        for ii = 1:ncomponents 
            alltfs = exp(-1i*kvec*(alldists(ii)-Rstart))./alldists(ii)...
                .*firstorderpathdata.specrefllist(ii,3).*(Sinputdata.sourceamplitudes( firstorderpathdata.specrefllist(ii,1),: ).');
            
           if Sinputdata.doaddsources == 1
              tfgeom(:,firstorderpathdata.specrefllist(ii,2)) = ...
                  tfgeom(:,firstorderpathdata.specrefllist(ii,2)) + alltfs;
           else
              tfgeom(:,firstorderpathdata.specrefllist(ii,2),firstorderpathdata.specrefllist(ii,1)) = alltfs;
           end
       end
       
        
    end
end

timingdata(2) = etime(clock,t00);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Diffraction

t00 = clock;

if difforder > 0

    if showtext >= 2
        disp(['      Generating first-order diffraction components']) 
    end
    
    if Sinputdata.doaddsources == 1
        tfdiff = zeros(nfrequencies,nreceivers);
    else
        tfdiff = zeros(nfrequencies,nreceivers,nsources);
    end

    iv = find(firstorderpathdata.edgeisactive);

    sou_vs_edges = sign(squeeze(sum(firstorderpathdata.diffpaths,1)));
    if size(sou_vs_edges,2) == 1
        sou_vs_edges = sou_vs_edges.';
    end
    rec_vs_edges = sign(squeeze(sum(firstorderpathdata.diffpaths,2)));
    if size(rec_vs_edges,2) == 1
        rec_vs_edges = rec_vs_edges.';
    end

    for ii = 1:length(iv)
        cylcoordS = zeros(nsources,3);
        cylcoordR = zeros(nreceivers,3);

        edgenumber = iv(ii);
        edgecoords = [edgedata.edgestartcoords(edgenumber,:);edgedata.edgeendcoords(edgenumber,:)];

        sourceandreceivercombos = squeeze(firstorderpathdata.diffpaths(:,:,edgenumber));
        iv2 = find(sourceandreceivercombos);
        [Rnumber,Snumber] = ind2sub([nreceivers,nsources],iv2);

        ivS = find(sou_vs_edges(:,edgenumber));
        ivR = find(rec_vs_edges(:,edgenumber));
        [rs,thetas,zs,rr,thetar,zr] = EDcoordtrans2(Sinputdata.coordinates(ivS,:),receivers(ivR,:),edgecoords,edgedata.edgenvecs(edgenumber,:));

        cylcoordS(ivS,:) = [rs thetas zs];
        cylcoordR(ivR,:) = [rr thetar zr];

        for jj = 1:length(iv2)
            [tfnew,singularterm,zfirst] = EDwedge1st_fd(envdata.cair,frequencies,edgedata.closwedangvec(edgenumber),...
                cylcoordS(Snumber(jj),1),cylcoordS(Snumber(jj),2),cylcoordS(Snumber(jj),3),...
                cylcoordR(Rnumber(jj),1),cylcoordR(Rnumber(jj),2),cylcoordR(Rnumber(jj),3),...
                edgedata.edgelengthvec(edgenumber)*[0 1],'n',Rstart,[1 1]);  

            tfnew = tfnew.*(Sinputdata.sourceamplitudes( Snumber(jj),: ).');
            if Sinputdata.doaddsources == 1
                tfdiff(:,Rnumber(jj)) =  tfdiff(:,Rnumber(jj)) + tfnew;                       
            else
                tfdiff(:,Rnumber(jj),Snumber(jj)) =  tfdiff(:,Rnumber(jj),Snumber(jj)) + tfnew;           
            end
        end

    end
else
   tfdiff = zeros(size(tfgeom));
end

timingdata(3) = etime(clock,t00);
    
    


