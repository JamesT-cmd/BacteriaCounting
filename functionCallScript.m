%count_bacteria('/Users/james/Documents/git_repos/bacteriaCounting/BacteriaCounting/pics/IMG_4465.DNG')
%thresholdGui('/Users/james/Documents/git_repos/bacteriaCounting/BacteriaCounting/pics/IMG_4465.DNG')
%detect_petri_dish(imread('/Users/james/Documents/git_repos/bacteriaCounting/BacteriaCounting/pics/IMG_4465.DNG'), 400, 700)
edge_detection_with_silders('/Users/james/Documents/git_repos/bacteriaCounting/BacteriaCounting/pics/IMG_4465.DNG')

    % Use the first detected circle (assuming it's the petri dish)
    % center = 1.0e+03 * [2.6543 1.0649] %centers(1, :);
    % radius = 573.5920 %radii(1);