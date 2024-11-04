function detect_petri_dish_advanced(img, minRadius, maxRadius)
    % Convert to grayscale if the image is in color
    if size(img, 3) == 3
        img_gray = rgb2gray(img);
    else
        img_gray = img;
    end

    % Step 1: Enhance contrast using adaptive histogram equalization
    img_enhanced = adapthisteq(img_gray, 'ClipLimit', 0.02, 'Distribution', 'rayleigh');

    % Step 2: Downscale the image to improve processing speed
    scaleFactor = 0.5;
    img_small = imresize(img_enhanced, scaleFactor);

    % Step 3: Apply Gaussian blur to reduce noise and smooth edges
    img_blurred = imgaussfilt(img_small, 2);

    % Step 4: Detect edges using Canny edge detector
    edges = edge(img_blurred, 'Canny', [0.08, 0.15]);

    % Step 5: Attempt circle detection with `imfindcircles`
    scaledRadiusRange = [minRadius, maxRadius] * scaleFactor;
    [centers, radii] = imfindcircles(edges, scaledRadiusRange, 'Sensitivity', 0.9, 'EdgeThreshold', 0.1);

    % If no circles are detected, try alternative detection with `regionprops`
    if isempty(centers)
        disp('No circles found with imfindcircles, trying regionprops with circularity check.');

        % Convert the edge-detected image to binary and fill holes
        bw = imfill(edges, 'holes');

        % Find connected components and filter by circularity
        stats = regionprops(bw, 'Centroid', 'EquivDiameter', 'Circularity');
        circularRegions = stats([stats.Circularity] > 0.7); % Keep regions with high circularity

        % Filter regions by radius range
        circularRegions = circularRegions([circularRegions.EquivDiameter] / 2 >= scaledRadiusRange(1) & ...
                                          [circularRegions.EquivDiameter] / 2 <= scaledRadiusRange(2));

        % Convert the detected regions to center and radius format
        if ~isempty(circularRegions)
            centers = cat(1, circularRegions.Centroid) / scaleFactor;
            radii = [circularRegions.EquivDiameter] / (2 * scaleFactor);
        else
            disp('No suitable circular regions detected with regionprops.');
            return;
        end
    else
        % Rescale centers and radii to the original image size if `imfindcircles` found circles
        centers = centers / scaleFactor;
        radii = radii / scaleFactor;
    end

    % Display the results on the original image
    figure;
    imshow(img); hold on;
    viscircles(centers, radii, 'EdgeColor', 'b');
    title('Detected Circles on Original Image');
    hold off;
end
