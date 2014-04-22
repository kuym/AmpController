volume = 0;
volumeMax = 10;
muted = 0;

function currentVolume()
	percentStr = tostring(math.floor(100 * volume / volumeMax)) .. "%";
	
	if(muted == 1) then
		return("muted " .. percentStr);
	else
		return(percentStr);
	end
end

function onEvent(event, value)

	if(event == "init") then
		
		print("init:", value);

	elseif(event == "key") then
		if(value == 11) then		--volume down
			volume = volume - 1;
			if(volume < 0) then
				volume = 0;
			end

		elseif(value == 10) then	--volume up
			volume = volume + 1;
			if(volume > volumeMax) then
				volume = volumeMax;
			end
			muted = 0;	-- special case: pressing volume-up should unmute if muted

		elseif(value == 12) then	--toggle mute
			print("mute key");
 			if(muted == 0) then
				muted = 1;
			else
				muted = 0;
			end

		end
		
		setMuted(muted);
		print("mute: " .. value .. ", " .. tostring(muted));
		setStatus("Dummy ok, volume " .. currentVolume());
		setVolume(volume / volumeMax);

	elseif(event == "serial") then
		setStatus("Dummy ok, volume " .. currentVolume());
		setVolume(volume / volumeMax);

	elseif(event == "volume") then
		if(value > 1) then
			value = 1;
		end
		if(value < 0) then
			value = 0;
		end
		volume = volumeMax * value;
		setStatus("Dummy ok, volume " .. currentVolume());
		setVolume(volume / volumeMax);

	elseif(event == "mute") then
		print("mute: " .. value .. ", " .. tostring(muted));
		muted = value;
		setStatus("Dummy ok, volume " .. currentVolume());
		setMuted(muted);

	end
	
end


setStatus("Dummy ok");
--setSerialBaud(9600);
