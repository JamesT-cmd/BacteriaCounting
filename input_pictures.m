function bacteria_gui()
    % Main GUI window using uifigure
    fig = uifigure('Name', 'Bacteria Analysis', 'Position', [100 100 1200 600]);

    % Create Axes for displaying the images
    axLeft = uiaxes(fig, 'Position', [50 150 500 400]);  % Original image
    axRight = uiaxes(fig, 'Position', [650 150 500 400]); % Transformed image
    axis(axLeft, 'off');  % Disable axes lines
    axis(axRight, 'off');  % Disable axes lines

    % Initialize the original and transformed images
    imgLeft = [];
    imgRight = [];

    % Load initial image
    imgLeft = loadHardcodedImage(axLeft);

    % Threshold Slider
    uilabel(fig, 'Position', [50 50 100 30], 'Text', 'Threshold');
    thresholdSlider = uislider(fig, 'Position', [150 65 150 3], 'Limits', [0 255], 'Value', 128, ...
        'ValueChangedFcn', @(sld, event) applyThreshold());

    % Sobel Edge Detection Slider
    uilabel(fig, 'Position', [350 50 150 30], 'Text', 'Sobel Strength');
    sobelSlider = uislider(fig, 'Position', [500 65 150 3], 'Limits', [0 10], 'Value', 1, ...
        'ValueChangedFcn', @(sld, event) applySobel());

    % Top-Hat Filter Slider (Disk Kernel Size)
    uilabel(fig, 'Position', [700 50 150 30], 'Text', 'Top-Hat Kernel Size');
    tophatSlider = uislider(fig, 'Position', [850 65 150 3], 'Limits', [1 50], 'Value', 15, ...
        'ValueChangedFcn', @(sld, event) applyTophat());

    % Detect Circle Button
    detectCircleButton = uibutton(fig, ...
        'Position', [1050 50 150 30], 'Text', 'Detect Circle', ...
        'ButtonPushedFcn', @(btn, event) openImageInFigure());

    % Confirm Button
    confirmButton = uibutton(fig, ...
        'Position', [1050 100 150 30], 'Text', 'Confirm Changes', ...
        'ButtonPushedFcn', @(btn, event) confirmChanges());

    % Callback: Load hardcoded image and display it
    function img = loadHardcodedImage(ax)
        imgPath = '/Users/james/Documents/git_repos/bacteriaCounting/BacteriaCounting/pics/IMG_4465.DNG';
        img = imread(imgPath);  % Load the image
        imshow(img, 'Parent', ax, 'InitialMagnification', 'fit');
        title(ax, 'Original Image');
    end

    % Apply Threshold Filter
    function applyThreshold()
        thresholdValue = thresholdSlider.Value;
        if size(imgLeft, 3) == 3
            imgGray = rgb2gray(imgLeft);
        else
            imgGray = imgLeft;
        end
        imgRight = imgGray > thresholdValue;
        updateRightImage('Threshold Applied');
    end

    % Apply Sobel Edge Detection Filter
    function applySobel()
        sobelStrength = sobelSlider.Value;
        if size(imgLeft, 3) == 3
            imgGray = rgb2gray(imgLeft);
        else
            imgGray = imgLeft;
        end
        sobelEdges = sobelStrength * edge(imgGray, 'sobel');
        imgRight = uint8(255 * sobelEdges);  % Convert to uint8
        updateRightImage('Sobel Edge Detection');
    end

    % Apply Top-Hat Filter
    function applyTophat()
        kernelSize = round(tophatSlider.Value);
        se = strel('disk', kernelSize);
        if size(imgLeft, 3) == 3
            imgGray = rgb2gray(imgLeft);
        else
            imgGray = imgLeft;
        end
        imgRight = imtophat(imgGray, se);
        updateRightImage('Top-Hat Filter');
    end

    % Update the right-side image
    function updateRightImage(effect)
        imshow(imgRight, 'Parent', axRight, 'InitialMagnification', 'fit');
        title(axRight, effect);
    end

    % Callback: Detect Circle using ginput and imfindcircles
    function openImageInFigure()
        if isempty(imgLeft)
            uialert(fig, 'No image loaded!', 'Error');
            return;
        end

        % Open a new figure and display the image
        tempFig = figure;
        imshow(imgLeft, 'InitialMagnification', 'fit');
        title('Select 3 Points on the Circle');

        % Use ginput to get 3 points from the user
        points = ginput(3);

        % Calculate the circle's center and radius
        [center, radius] = findCircle(points);

        % Close the temporary figure
        close(tempFig);

        % Use imfindcircles to refine the circle detection
        [bestCenter, bestRadius] = refineCircle(imgLeft, center, radius);

        % Crop and mask the image based on the refined circle
        imgRight = cropAndMaskCircle(imgLeft, bestCenter, bestRadius);

        % Display the refined image on the right
        imshow(imgRight, 'Parent', axRight, 'InitialMagnification', 'fit');
        title(axRight, 'Refined Circle with Mask');
    end

    % Helper function: Calculate the circle from 3 points
    function [center, radius] = findCircle(points)
        x1 = points(1, 1); y1 = points(1, 2);
        x2 = points(2, 1); y2 = points(2, 2);
        x3 = points(3, 1); y3 = points(3, 2);

        % Midpoints and slopes of perpendicular bisectors
        mid1 = [(x1 + x2) / 2, (y1 + y2) / 2];
        mid2 = [(x2 + x3) / 2, (y2 + y3) / 2];
        slope1 = -1 / ((y2 - y1) / (x2 - x1));
        slope2 = -1 / ((y3 - y2) / (x3 - x2));

        % Solve for intersection (circle center)
        A = [-slope1, 1; -slope2, 1];
        B = [mid1(2) - slope1 * mid1(1); mid2(2) - slope2 * mid2(1)];
        center = A \ B;
        radius = sqrt((center(1) - x1)^2 + (center(2) - y1)^2);
    end

    % Helper function: Refine circle using imfindcircles
    function [refinedCenter, refinedRadius] = refineCircle(img, initialCenter, initialRadius)
        if size(img, 3) == 3
            imgGray = rgb2gray(img);
        else
            imgGray = img;
        end

        radiusRange = [floor(initialRadius * 0.9), ceil(initialRadius * 1.1)];
        [centers, radii] = imfindcircles(imgGray, radiusRange, 'Sensitivity', 0.95);

        if ~isempty(centers)
            [~, idx] = min(vecnorm(centers - initialCenter, 2, 2));
            refinedCenter = centers(idx, :);
            refinedRadius = radii(idx);
        else
            refinedCenter = initialCenter;
            refinedRadius = initialRadius;
        end
    end

    % Helper function: Crop and mask the circle region
    function maskedImage = cropAndMaskCircle(img, center, radius)
        [rows, cols, ~] = size(img);
        xMin = max(1, floor(center(1) - radius));
        xMax = min(cols, ceil(center(1) + radius));
        yMin = max(1, floor(center(2) - radius));
        yMax = min(rows, ceil(center(2) + radius));
        croppedImage = img(yMin:yMax, xMin:xMax, :);

        [X, Y] = meshgrid(1:(xMax - xMin + 1), 1:(yMax - yMin + 1));
        mask = ((X - radius).^2 + (Y - radius).^2) <= radius^2;
        maskedImage = uint8(zeros(size(croppedImage)));
        for c = 1:size(img, 3)
            channel = croppedImage(:, :, c);
            channel(~mask) = 0;
            maskedImage(:, :, c) = channel;
        end
    end

    % Confirm Changes: Replace Left Image with Right Image
    function confirmChanges()
        if isempty(imgRight)
            uialert(fig, 'No transformation to confirm!', 'Error');
            return;
        end
        imgLeft = imgRight;
        imshow(imgLeft, 'Parent', axLeft, 'InitialMagnification', 'fit');
        title(axLeft, 'Updated Image');
    end
end
