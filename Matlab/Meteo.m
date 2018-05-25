classdef Meteo
    methods(Static)
        function out = plot_2d_fft(data, varargin)
            
            validateattributes(data, {'numeric'}, {'2d', 'nonempty', 'finite', 'nonnan'});
            
            args = struct('samp_rate', 1, 'logscale', 0, 'fftshift', true);
            args = staux('parse_args', varargin, args, {'logscale'});
            
            nx = size(data, 2);
            ny = size(data, 1);
        
            samp_rate = args.samp_rate;
            
            validateattributes(samp_rate, {'numeric'}, {'scalar', 'positive', 'real',
                               'finite', 'nonnan'});
            
            if isscalar(samp_rate)
                samp_x = 1 / samp_rate;
                samp_y = 1 / samp_rate;
            else
                samp_x = 1 / samp_rate(2);
                samp_y = 1 / samp_rate(1);
            end
            
            x_fr = (-nx / 2 : nx / 2 - 1) * samp_x / nx;
            y_fr = (-ny / 2 : ny / 2 - 1) * samp_y / ny;
        
            h = figure();
            
            if args.fftshift
                matrix = fftshift(data);
            end
            
            if args.logscale
                imagesc(x_fr, y_fr, log10(abs(data)));
            else
                imagesc(x_fr, y_fr, abs(data));
            end
        
            colorbar;
            % saveas(h, args.out);
            
            out.h = h;
            out.x_fr = x_fr;
            out.y_fr = y_fr;
        end % plot_2d_fft
        
        function butter = butter_filter(matrix_size, low_pass, varargin)
        % Adapted from StaMPS by Andy Hooper
        
            validateattributes(matrix_size, {'numeric'}, {'nonempty', 'positive', 'finite'});
            validateattributes(low_pass, {'numeric'}, {'scalar', 'positive', 'finite'});
            
            args = struct('order', 5, 'samp_rate', 1)
            args = staux('parse_args', varargin, args);
            
            samp_rate = args.sampe_rate;
            order     = args.order;
        
            validateattributes(samp_rate, {'numeric'}, {'nonempty', 'positive', 'finite', 'nonnan'});
            validateattributes(order, {'numeric'}, {'scalar', 'positive', 'finite', 'nonnan'});
        
            if isscalar(matrix_size)
                nx = msize;
                ny = msize;
            else
                nx = msize(2);
                ny = msize(1);
            end    
            
            low_pass_wavelength = low_pass;
            k0 = 1 / low_pass_wavelength;
            
            if isscalar(samp_rate)
                samp_x = samp_rate;
                samp_y = samp_rate;
            else
                samp_x = samp_rate(2);
                samp_y = samp_rate(1);
            end
            
            kx = (-nx / 2 : nx / 2 - 1) * samp_x / nx;
            ky = (-ny / 2 : ny / 2 - 1) * samp_y / ny;
                
            [kx, ky] = meshgrid(kx, ky);
            
            k_dist = sqrt( kx.^2 + ky.^2 );
            
            butter = 1 ./ (1 + (k_dist ./ k0).^(2*order));
        end % butter_filter
        
        function abs_phase = invert_abs(phase, varargin)
            validateattributes(phase, {'numeric'}, {'nonempty', 'finite', 'ndims', 2, 'nonnan'});
            
            args = struct('last_row', 0.0, 'master_idx', 1);
            args = staux('parse_args', varargin, args);
        
            master_idx = args.master_idx;
            last       = args.last_row;
            
            validateattributes(last, {'numeric'}, {'nonempty', 'vector', 'finite', 'nonnan'});
            validateattributes(master_idx, {'numeric'}, {'scalar', 'positive', ...
                               'finite', 'integer', 'nonnan'});
            
            [n_ps, n_ifg] = size(phase);
            
            n_sar = n_ifg + 1;
            
            design = zeros(n_ifg, n_sar);
            design(:, master_idx) = 1.0;
            
            slaves = - diag(ones(n_ifg, 1));
            
            if master_idx == 1
                design(:,2:end) = slaves;
            elseif master_idx == n_sar
                design(:,1:end-1) = slaves;
            else
                idx = master_idx - 1;
                design(1:idx, 1:idx) = slaves(1:idx, 1:idx);
                
                idx = master_idx + 1;
                design(master_idx:end, idx:end) = slaves(master_idx:end, master_idx:end);
            end
            
            clear slaves;
            
            design = [design; ones(1, n_sar)];
            
            if isscalar(last) && last == 0.0
                phase = [phase'; zeros(1, n_ps)];
            else
                if iscolumn(last)
                    phase = transpose([phase, last]);
                else
                    phase = [transpose(phase); last];
                end
            end
            
            abs_phase = lscov(design, double(phase));
        end % invert_abs
        
        function abs_phase = invert_phase_stamps(varargin)
            
            args = struct('average', 0.0);
            args = staux('parse_args', varargin, args);
            
            average = args.average;
            validateattributes(average, {'numeric'}, {'scalar', 'nonempty', 'vector', ...
                               'finite', 'nonnan'});
            
            ph = load('phuw2.mat');
            ps = load('ps2.mat');
            
            phase = ph.ph_uw;
            master_idx = ps.master_ix;
            
            clear ph ps;
         
            phase(:,master_idx) = [];
            
            abs_phase = invert_abs(phase, 'master_idx', master_idx, 'average', average);
        end % invert_phase_stamps
        
        function corrected_phase = subtract_dry()
        
            ph_uw = load('phuw2.mat');
            ph_uw = ph_uw.ph_uw;
            
            ph_tropo = load('tca2.mat');
        
            corrected_phase = ph_uw - ph_tropo.ph_tropo_era_hydro;
        end
        
        function d_total = total_aps(varargin)
        % Based on the `aps_weather_model_InSAR` function of the TRAIN packege.
            
            args = struct('outdir', '.');
            args = staux('parse_args', varargin, args);
            
            outdir = args.outdir;
            
            validateattributes(outdir, {'char'}, {'nonempty'});
            
            % radar wavelength in cm
            lambda         = getparm_aps('lambda', 1) * 100;
            ll_matfile     = getparm_aps('ll_matfile',1);
            ifgday_matfile = getparm_aps('ifgday_matfile');
            weather_model_datapath = getparm_aps('era_datapath',1);
            
            % Filename suffix of the output files
            wetoutfile = '_ZWD.xyz';   
            hydroutfile = '_ZHD.xyz'; 
            
            % Filename suffix of the output files
            outfile = '.ztd';
            
            % assumed date structure for era
            datestructure = 'yyyymmdd';
            
            % loading the data
            fprintf('Stamps processed structure \n')
            ps = load(ll_matfile);
            load psver
            dates = ps.day;
            lonlat = ps.lonlat;
            
            %azi_inc = staux('load_azi_inc');
            %inc_angle = azi_inc(:,2);
            
            % getting the dropped ifgs
            drop_ifg_index = getparm('drop_ifg_index');
        
            % getting the parms file list from stamps to see the final ifg list
            if strcmp(getparm('small_baseline_flag'),'y')
                sb_flag = 1;
            else
                sb_flag = 0;
            end
            
            n_ifg = ps.n_ifg;
        
            % constructing the matrix with master and slave dates
            if sb_flag ==1
                % for SB
                ifg_number = [1:n_ifg]';
                ifgday_ix = ps.ifgday_ix;
                % removing those dropped interferograms
                ifgday_ix(drop_ifg_index,:) =[];
                ifg_number(drop_ifg_index)=[];
        
                % defining ix interferograms for which the delay needs to be computed
                ifgs_ix = [ifgday_ix ifg_number];
            else
                % slightly different for PS.
                date_slave_ix = [1:n_ifg]';
                ifg_number = [1:n_ifg]';
        
                % removing those interferograms that have been dropped
                date_slave_ix(drop_ifg_index)=[];
                ifg_number(drop_ifg_index)=[];
        
                % the master dates
                date_master_ix = repmat(ps.master_ix,size(date_slave_ix,1),1);
        
                % ix interferograms
                ifgs_ix = [date_master_ix date_slave_ix ifg_number];
            end
            
            n_dates = length(dates);
            InSAR_datapath = ['.'];
            apsname = fullfile(InSAR_datapath, 'tca', num2str(psver), '.mat');
            apssbname = fullfile(InSAR_datapath, 'tca_sb', num2str(psver), '.mat');
        
            %% loading the weather model data
            % initialisation
            
            % these are the SAR estimated tropospheric delays for all data
            d_wet   = NaN([size(lonlat,1) n_dates]);
            d_hydro = NaN([size(lonlat,1) n_dates]);
            d_total = NaN([size(lonlat,1) n_dates]);
            flag_wet_hydro_used = 'n';
        
            ix_no_weather_model_data = [];
            counter = 0;
        
            % looping over the dates 
            for k = 1:n_dates
                % getting the SAR data and convert it to a string
                date_str = datestr(ps.day(k,1), datestructure);
        
                % filenames
                model_filename_wet = fullfile(weather_model_datapath, date_str, ...
                                              [date_str, wetoutfile]);
                model_filename_hydro = fullfile(weather_model_datapath, date_str, ...
                                                [date_str, hydroutfile]);
                model_filename = fullfile(weather_model_datapath, date_str, ...
                                          [date_str, outfile]);
        
                % checking if there is actual data for this date, if not just
                % leave NaN's in the matrix.
                
                if exist(model_filename_wet, 'file') == 2
                    flag_wet_hydro_used = 'y';
                    
                    % computing the dry delay
                    [xyz_input, xyz_output] = ...
                            load_weather_model_SAR(model_filename_hydro, double(lonlat));
                    
                    % saving the data which have not been interpolated
                    d_hydro(:,k) = xyz_output(:,3);
                    clear xyz_input xyz_output
                    
                    
                    % computing the wet delays
                    [xyz_input, xyz_output] = ...
                                load_weather_model_SAR(model_filename_wet, double(lonlat));
                     
                    % saving the output data
                    d_wet(:,k) = xyz_output(:,3);
                    clear xyz_output
                    counter = counter+1;
                elseif exist(model_filename, 'file') == 2
                    flag_wet_hydro_used = 'n';
                    
                    % this is the GACOS model file, will need to pass the model-type as
                    % its grid-note 
                    
                    [xyz_input, xyz_output] = ...
                        load_weather_model_SAR(model_filename, double(lonlat), [], model_type);
                    
                    % saving the output data
                    d_total(:,k) = xyz_output(:,3);
                    clear xyz_output
                    counter = counter+1;
                else
                    % rejected list of weather model images
                    ix_no_weather_model_data = [ix_no_weather_model_data k];
                end
                clear model_filename_hydro model_filename_wet date_str
            end
            fprintf([num2str(counter) ' out of ' num2str(n_dates) ...
                      ' SAR images have a tropospheric delay estimated \n'])
        
        
            %% Computing the type of delay
            if strcmpi(flag_wet_hydro_used,'y')
                d_total = d_hydro + d_wet;
            end
        
            staux('save_binary', d_total, fullfile(outdir, 'd_total.dat'));
            staux('save_binary', d_hydro, fullfile(outdir, 'd_hydro.dat'));
            staux('save_binary', d_wet,   fullfile(outdir, 'd_wet.dat'));
        
            %% Converting the Zenith delays to a slant delay
            %if size(inc_angle, 2) > 1 && size(inc_angle, 1) == 1
                %inc_angle = inc_angle';
            %end
            
            %if size(inc_angle, 2) == 1
                %inc_angle = repmat(inc_angle, 1, size(d_total, 2));
                %if size(inc_angle, 1) == 1
                    %inc_angle = repmat(inc_angle, size(d_total,1), 1);
                %end
            %end
            
            % d_total = d_total ./ cos(deg2rad(inc_angle));
            %% Converting the range delay to a phase delay
            % converting to phase delay. 
            % The sign convention is such that ph_corrected = ph_original - ph_tropo*
            % d_total = -4 * pi ./ lambda .* d_total;    
        end % total_aps
        
        function Z = geopot2h(geopot, latgrid)
            
            klass = {'numeric'};
            attr = {'2d', 'finite', 'nonnan', 'nonempty'};
            validateattributes(geopot, klass, attr);
            validateattributes(latgrid, klass, attr);
            
            % Convert Geopotential to Geopotential Height and then to Geometric Height
            g0 = 9.80665;
            % Calculate Geopotential Height, H
            H = geopot./g0;
        
            % map of g with latitude
            g = 9.80616.*(1 - 0.002637.*cosd(2.*latgrid) + 0.0000059.*(cosd(2.*latgrid)).^2);
            % map of Re with latitude
            Rmax = 6378137; 
            Rmin = 6356752;
            Re = sqrt(1./(((cosd(latgrid).^2)./Rmax^2) + ((sind(latgrid).^2)./Rmin^2)));
        
            % Calculate Geometric Height, Z
            Z = (H.*Re)./(g/g0.*Re - H);
        end % geopot2h
        
        function [] = aps_setup(lonlat_extend)
            
            attr = {'scalar', 'finite', 'nonnan', 'positive'};
            validateattributes(lonlat_extend, {'numeric'}, attr);
            
            % preprocessor type
            preproc = getparm('insar_processor');
        
            if strcmp(preproc, 'doris')
                % open dem parameters file
                dem_params = staux('sfopen', demparms.in', 'r');
                dem_path = fgetl(dem_params);
            elseif strcmp(preproc, 'gamma')
                dem_params = '../dem/dem_seg.par';
                dem_path = '../dem/dem_seg_swapped.dem';
            else
                error(['Unrecognized preprocessor ', preproc]);
            end
            
            % get dem file path
            setparm_aps('demfile', dem_path);
            setparm_aps('era_datapath', fullfile(pwd, 'era'));
            setparm_aps('merra_datapath', fullfile(pwd, 'merra2'));
            setparm_aps('gacos_datapath', fullfile(pwd, 'gacos'));
            
            setparm_aps('lambda', getparm('lambda'), 1);
            setparm_aps('heading', getparm('heading'), 1);
            
            % get dem file extension
            [~, ~, ext] = fileparts(dem_path);
            
            % creating rsc file if .dem is the file extension
            if strcmp(ext, '.dem')
                fprintf('DEM extension is .dem, creating, .dem.rsc file\n');
                dem_rsc = staux('sfopen', [dem_path, '.rsc'], 'w');
                
                if strcmp(preproc, 'doris')
                    % printing dem parameters
                    fprintf(dem_rsc, ['WIDTH ', fgetl(dem_params), '\n']);
                    fprintf(dem_rsc, ['LENGTH ', fgetl(dem_params), '\n']);
                    fprintf(dem_rsc, ['X_FIRST ', fgetl(dem_params), '\n']);        
                    fprintf(dem_rsc, ['Y_FIRST ', fgetl(dem_params), '\n']);
                
                    % x and y step size
                    step = fgetl(dem_params);
        
                    fprintf(dem_rsc, ['X_STEP ', step, '\n']);
                    fprintf(dem_rsc, ['Y_STEP ', '-', step, '\n']);
                    fprintf(dem_rsc, ['FORMAT ', fgetl(dem_params), '\n']);
                    fclose(dem_params);
                elseif strcmp(preproc, 'gamma')
                    % printing dem parameters
                    fprintf(dem_rsc, ['WIDTH ', num2str(readparm(dem_params, 'width')), '\n']);
                    fprintf(dem_rsc, ['LENGTH ', num2str(readparm(dem_params, 'nlines')), '\n']);
                    fprintf(dem_rsc, ['X_FIRST ', num2str(readparm(dem_params, 'corner_lon')), '\n']);        
                    fprintf(dem_rsc, ['Y_FIRST ', num2str(readparm(dem_params, 'corner_lat')), '\n']);
                
                    fprintf(dem_rsc, ['X_STEP ', num2str(readparm(dem_params, 'post_lon')), '\n']);
                    fprintf(dem_rsc, ['Y_STEP ', num2str(readparm(dem_params, 'post_lat')), '\n']);
                    fprintf(dem_rsc, ['FORMAT ', readparm(dem_params, 'data_format'), '\n']);
                end
                fclose(dem_rsc);
            end
            
            % loading lonlat values, assuming processing was done by StaMPS
            ps2 = load('ps2.mat');
            lonlat = ps2.lonlat;
            clear ps2;
            
            min_lon = min(lonlat(:,1)); max_lon = max(lonlat(:,1));
            min_lat = min(lonlat(:,2)); max_lat = max(lonlat(:,2));
            
            lon_add = (max_lon - min_lon) * lonlat_extend;
            lat_add = (max_lat - min_lat) * lonlat_extend;
            
            setparm_aps('region_lon', [min_lon - lon_add, max_lon - lon_add]);
            setparm_aps('region_lat', [min_lat - lat_add, max_lat - lat_add]);
        end % aps_setup
        
        function [] = calc_wv()
        
            lambda = getparm_aps('lambda', 1) * 100;
            
            ph = load('phuw2.mat');
            ps = load('ps2.mat');
            
            phase = ph.ph_uw;
            master_idx = ps.master_ix;
            phase(:,master_idx) = [];
            
            ncols = ps.n_image + 2;
            
            clear ps ph
            
            % loading zenith delays
            d_total = staux('load_binary', 'd_total.dat', ncols);
            
            % lon., lat. coordinates (first two columns) are not required
            d_total = d_total(:,3:end);
            
            d_hydro = staux('load_binary', 'd_hydro.dat', ncols);
            d_hydro = d_hydro(:,3:end);
            
            d_wet = staux('load_binary', 'd_wet.dat', ncols);
            d_wet = d_wet(:,3:end);
            
            azi_inc = staux('load_binary', 'azi_inc.dat', 2);
            inc_angle = azi_inc(:,2); clear azi_inc
            
            if size(inc_angle, 2) > 1 && size(inc_angle, 1) == 1
                inc_angle = inc_angle';
            end
            
            if size(inc_angle, 2) == 1
                inc_angle = repmat(inc_angle, 1, size(d_total, 2));
                if size(inc_angle, 1) == 1
                    inc_angle = repmat(inc_angle, size(d_total, 1), 1);
                end
            end
            
            % Converting the zenith delays to slant delays 
            d_total = d_total ./ cos(deg2rad(inc_angle));
            d_hydro = d_hydro ./ cos(deg2rad(inc_angle));
            % phase = phase .* cos(deg2rad(inc_angle));
            
            %% Converting the range delay to a phase delay
            % The sign convention is such that ph_corrected = ph_original - ph_tropo*
            
            % d_total = -4 * pi ./ lambda .* d_total;
            
            % converting phase to delay
            phase = - (lambda / (4 * pi))  .* phase;
        
            % calculate average total delay for each SAR acquisition
            % d_avg = mean(d_total, 2);
            d_sum = sum(d_total, 2);
            
            abs_phase = transpose(invert_abs(phase, 'master_idx', master_idx, ...
                                             'last_row', d_sum));
            abs_wet = abs_phase - d_hydro;
            
            h = figure('visible', 'off');
            hist(rms(abs_wet - d_wet));
            title(['Distribution of the difference RMS values between inverted and ', ...
                   'weather model water vapour slant delay values.']);
            xlabel('RMS difference for IFGs [cm]');
            ylabel('Frequency');
            saveas(h, 'dinv_rms_wv.png');
        
            h = figure('visible', 'off');
            hist(rms(abs_phase - d_total));
            title(['Distribution of the difference RMS values between inverted and ', ...
                   'weather model total slant delay values.']);
            xlabel('RMS difference for IFGs [cm]');
            ylabel('Frequency');
            saveas(h, 'dinv_rms_total.png');
            
            staux('save_binary', abs_phase, 'dinv_total.dat');
            staux('save_binary', abs_wet, 'dinv_wet.dat');
        end % calc_wv
        
        function ret = rms(data)
            
            validateattributes(data, {'numeric'}, {'finite', '2d', 'nonnan'});
            ret = sqrt( mean(data.^2, 2) );
        end
    end % methods
end % Meteo

%function out = meteo(fun, varargin)
%% TRAIN Axilliary functions.
%%
%% Based on codes by David Bekaert and Andrew Hooper from packages TRAIN
%% (https://github.com/dbekaert/TRAIN) and
%% StaMPS (https://homepages.see.leeds.ac.uk/~earahoo/stamps/).
%%

    %switch(fun)
        %case 'plot_2d_ftt'
            %out = plot_2d_fft(varargin{:});
        %case 'butter_filter'
            %out = buttter_filter(varargin{:});
        %case 'subtract_dry'
            %out = subtract_dry(varargin{:});
        %case 'invert_abs'
            %out = invert_abs(varargin{:});
        %case 'invert_phase_stamps'
            %out = invert_phase_stamps(varargin{:});
        %case 'zero_outlier'
            %out = zero_outlier(varargin{:});
        %case 'total_aps'
            %out = total_aps(varargin{:});
        %case 'aps_setup'
            %aps_setup(varargin{:})
        %case 'geopot2h'
            %out = geopot2h(varargin{:})
        %case 'calc_wv'
            %calc_wv()
        %otherwise
            %error(['Unknown function ', fun]);
    %end
%end % meteo