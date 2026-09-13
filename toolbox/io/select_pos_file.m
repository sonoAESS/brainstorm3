function varargout = select_pos_file(varargin)
% SELECT_POS_FILE: Select the best .pos (Polhemus) file among several candidates.
%
% USAGE:  pos_file = select_pos_file('SelectPosFile', posFiles, verbose=1)
%         score    = select_pos_file('ScorePosFile', ChannelMat)
%
% When several .pos files are available for the same CTF dataset, Brainstorm cannot know which one
% to use. This function picks, in a deterministic way, the file that is most likely to contain the
% complete digitization: it has all the anatomical fiducials (NAS/LPA/RPA), the most head coils
% (HPI-N/L/R) and the most digitized points. A clear message is displayed for the user.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@

eval(macro_method);
end


%% ===== SELECT POS FILE =====
function pos_file = SelectPosFile(posFiles, verbose, isInteractive)
    % SELECT_POS_FILE: Select the best .pos file among the given candidates.
    %
    % INPUT:
    %    - posFiles      : Cell array of full paths to the .pos candidate files
    %    - verbose       : If 1, display the selection in the command window
    %    - isInteractive : If 1, ask the user to confirm/change the selection in a dialog box,
    %                      with the best-scored file pre-selected. Optional, default: 0 (the
    %                      best-scored file is selected automatically, deterministically).
    % OUTPUT:
    %    - pos_file      : Full path to the selected file, or [] if no file could be read
    pos_file = [];
    % Parse inputs
    if (nargin < 2) || isempty(verbose)
        verbose = 1;
    end
    if (nargin < 3) || isempty(isInteractive)
        isInteractive = 0;
    end
    if ischar(posFiles)
        posFiles = {posFiles};
    end
    % Loop on all the candidate files
    scores = -ones(1, length(posFiles));
    for i = 1:length(posFiles)
        % Try to read the file (skip the ones that cannot be read)
        try
            ChannelMat = in_channel_pos(posFiles{i});
            scores(i) = select_pos_file('ScorePosFile', ChannelMat);
        catch
            scores(i) = -1;
            disp(['CTF> Warning: Could not read the Polhemus file, ignoring: ' posFiles{i}]);
        end
    end
    % None of the files could be read: nothing to select
    if all(scores < 0)
        disp('CTF> Warning: None of the Polhemus files could be read, no head points will be imported.');
        return;
    end
    % Select the best scored file (strictly better, to keep the selection deterministic)
    [bestScore, iBest] = max(scores);
    pos_file = posFiles{iBest};
    % Interactive session: let the user confirm the automatic selection, or choose another file.
    % In batch/headless mode the best-scored file is selected automatically.
    if isInteractive && (length(posFiles) > 1)
        dialogMsg = ['Multiple .pos (Polhemus) files were found in the dataset folder. ' ...
                     'The file recommended below is the one most likely to contain the complete ' ...
                     'digitization of the head (the highest score). ' ...
                     'Please confirm this file, or select another one if needed.'];
        iChoice = java_dialog('radio', dialogMsg, 'Select the .pos file to import', [], posFiles, iBest);
        % If the user cancelled the dialog: keep the automatic selection
        if ~isempty(iChoice)
            pos_file = posFiles{iChoice};
            bestScore = scores(iChoice);
        end
    end
    % Report the selection
    if verbose
        disp(['CTF> Multiple .pos files found, selected: ' pos_file ' (score: ' num2str(bestScore) ')']);
        disp('BST> Warning: Please verify that the selected .pos file is the correct one.');
    end
end


%% ===== SCORE POS FILE =====
function score = ScorePosFile(ChannelMat)
    % SCORE_POS_FILE: Score a digitized head points file, to select which file is the most likely
    % to contain the complete digitization of the head.
    % Heuristics (deterministic; the largest weight guarantees that a file with the anatomical
    % fiducials always beats a file with only digitized points):
    %   +1000 for each anatomical fiducial (NAS/LPA/RPA)
    %     +10 for each MEG head coil (HPI-N/L/R)
    %      +1 for each additional digitized point
    % INPUT:
    %    - ChannelMat : Channel structure read from a .pos file (in_channel_pos)
    % OUTPUT:
    %    - score      : Sum of the weighted components listed above
    score = 0;
    % Head points
    if isfield(ChannelMat, 'HeadPoints') && isfield(ChannelMat.HeadPoints, 'Label') && isfield(ChannelMat.HeadPoints, 'Loc') && ~isempty(ChannelMat.HeadPoints.Label)
        labels = ChannelMat.HeadPoints.Label;
        % +1000 for each anatomical fiducial
        score = score + 1000 * any(strcmpi(labels, 'Nasion') | strcmpi(labels, 'NAS'));
        score = score + 1000 * any(strcmpi(labels, 'Left')   | strcmpi(labels, 'LPA'));
        score = score + 1000 * any(strcmpi(labels, 'Right')  | strcmpi(labels, 'RPA'));
        % +10 for each MEG head coil
        score = score + 10 * sum(strcmpi(labels, 'HPI-N') | strcmpi(labels, 'HPI-L') | strcmpi(labels, 'HPI-R'));
        % +1 for each digitized point
        score = score + length(labels);
    end
end