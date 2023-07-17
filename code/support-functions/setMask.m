function [p, data_obj] = setMask(p, A)
%SETMASK Mask relevant pixels
%   Accepts multiple types of masks in various ways. Standardizes output to
%   be a 2D matrix of mask_chosen_pixels x time within params. 
%
%   MASK OPTIONS:
%       (1) - Binary mask - mask should be a 2D logical or binary mask 
%               
%       (2) - Pre-computed mask - 
%
%
% :param p: Parameters used for running GraFT. Particularly of interest are
%           fieldnames:
%           - .mask : implements user selected mask options
%                     type: logical / string
% :type p: Struct
%
% :returns: struct :p: Parameters with default mask field as a 2D matrix of
%                      mask_selected_pixels x time. Also adds two extra
%                      fields responsible for tracking size of data_obj:
%                       - .nRows: data object rows
%                           type: double
%                       - .nCols: data object columns
%                           type: double
%
% PRE-COMPUTED OPTIONS
% 'Sigma'    -  calculates the threshold based on the mean and standard 
%               deviation of the data. Pixels with activity above the 
%               threshold are considered part of the regions of interest.
% 'Adaptive' -  applies adaptive thresholding, where the threshold is 
%               computed locally based on the neighborhood around each 
%               pixel.
% 'Otsu'     -  utilizes Otsu's thresholding, which automatically 
%               determines the threshold based on the shape of the 
%               histogram to separate foreground and background.
% 'Triangle' -  applies Triangle thresholding, which calculates the 
%               threshold based on the histogram shape. This technique is
%               particularly effective when the object pixels produce a 
%               weak peak in the histogram.
%
%
% 06.27.2023 - Alex Estrada - %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Input Parsing
% Initializing flag
check = false;
flag = "";
switch  true
    % pre-computed selection
    case isstring(p.mask) || ischar(p.mask)
        if isstring(p.mask)
            p.mask = char(p.mask);
        end
        options = {'sigma', 'adaptive', 'otsu', 'triangle'};
        % compare
        check = any(strcmpi(p.mask), options);
        if ~check
            flag = sprintf("Selection for mask '%s' not recognized.\n" + ...
                "Currently only supports the following options for " + ...
                "pre-computed masks: %s, %s, %s, %s", p.mask, options{:});
        end

    % load binary mask
    case ismatrix(p.mask)
        % if empty
        if isempty(p.mask); return; end
        
        % check mask
        if ~islogical(p.mask)
            eror('Mask not binary. Ensure it is type logical and try again.')
        end

        % mask size
        if size(p.mask, 3) == 1
            [p.nRows, p.nCols] = size(p.mask);
        else
            error('3D mask not supported')
        end
        
        % compatability
        if size(A, 1) == p.nRows && size(A, 2) == p.nCols                  % original_pixels x original_pixels x time
            temp = reshape(A, [], size(A,3));
            % change to mask_pixels x time
            data_obj = temp(p.mask(:), :);
            return
        elseif size(A,1) == p.nRows*p.nCols                                % original_pixels x time
            % change to mask_pixels x time
            data_obj = A(p.mask(:), :);
            return
        elseif size(A,1) == numel(find(p.mask==1))                         % mask_pixels x time
            % mask already applied
            data_obj = A;
            return
        else
            error("Sizes of mask and data input do not match.\n" + ...
                  "Mask: %s\nData size: %s", ...
                  num2str(size(p.mask)), num2str([p.nRows, p.nCols]))
        end
end

%% Pre-Computed
if check
    binary_mask = zeros(size(A,1), size(A, 2)); % assuming 2D image stack
    
    if strcmpi('sigma', p.mask)
        %% Sigma Threshold
        % STD factor
        std_factor = 2;         % change?
        % mean pixel value (3rd dimension)
        mean_data = mean(A, 3);
        % STD pixel value (3rd dimension)
        std_data = std(data, [], 3);
        
        % threshold
        threshold = mean_data + std_factor * std_data;

        % binary mask
        binary_mask = A > threshold;
    
    elseif strcmpi('adaptive', p.mask)
        %% Adaptive Threshold
        % Adjust block size
        block_size = 25;

        % binary mask
        binary_mask = imbinarize(A, 'adaptie', 'BlockSize', block_size);
    
    elseif strcmpi('otsu', p.mask)
        %% Otsu's Threshold
        % mean pixel value (3rd dimension)
        mean_data = mean(A, 3);

        % Otsu's thresholding using mean pixel activity
        level = graythresh(A ./ mean_data);

        % binary mask
        binary_mask = imbinarize(A, level);

    elseif strcmpi('triangle')
        %% Triangle Threshold
        % level
        level = triangle_thresh(A);

        % binary mask
        binary_mask = false(size(A));
    end
    
    % Apply the binary mask to the data
%     masked_data = bsxfun(@times, A, binaryMask);

    % Update mask
    p.mask = binary_mask;

else
    % check == false
    warning(flag)
    % default val for mask
    p.mask = [];
    return
end

