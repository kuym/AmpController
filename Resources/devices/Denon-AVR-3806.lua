print("Denon");

function init()
	initialized = false;
	muted = 0;
	buffer = "";
	volume = 0;
	volumeMax = 0;
	volumeStep = 3;
	
	serialWrite("PW?\r");

	setStatus("Denon AVR-3806 pending.");
end

function parseVolumeLevel(str)

	v = tonumber(str);
	
	if(v == 99) then
		v = 0;	--odd Denon design
	elseif(str:len() == 3) then
		v = (v / 10);
	end
	
	return(v);
end

function formatVolume(value)
	
	v = "0";
	if(value <= 0) then	-- special case
		return("99");
	else
		value = math.floor(value * 2);	-- shift to 1/2 unit resolution
		
		if((value / 2) == math.floor(value / 2)) then
			v = tostring(math.floor(value / 2));		-- if even, "80"
		else
			v = tostring(math.floor(value / 2)) .. "5";	-- if odd, "825"
		end
	end
	if(value < 10) then
		v = "0" .. v;
	end
	return(v);
end

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
		init();

	elseif(event == "key") then

		if(value == 11) then		--volume down
			print("volume down key");
			--serialWrite("MVDOWN\r");
			serialWrite("MV" .. formatVolume(volume - volumeStep) .. "\r");

		elseif(value == 10) then	--volume up
			print("volume up key");
			--serialWrite("MVUP\r");
			if(muted == 1) then
				serialWrite("MUOFF\r");	-- special case: pressing volume-up should unmute if muted
			end

			serialWrite("MV" .. formatVolume(volume + volumeStep) .. "\r");

		elseif(value == 12) then	--toggle mute
			print("mute key");
			if(muted == 1) then
				serialWrite("MUOFF\r");
			else
				serialWrite("MUON\r");
			end
		
		end

	elseif(event == "serial") then
	
		if(value == "") then
			print("disconnected.");
			setStatus("Denon AVR-3806 disconnected.");
			init();
			return;
		end

		buffer = buffer .. value;
		
		--try to parse the message
		while(#buffer > 0) do
			
			offset = buffer:find("\r");

			if(offset == nil) then
				break;
			end

			response = buffer:sub(1, offset - 1);
			buffer = buffer:sub(offset + 1);

			print("Denon response:", response);
			
			if(response == "MUON") then		--mute on
				muted = 1;
				setStatus("Denon AVR-3806 ok, volume " .. currentVolume());
				setVolume(volume / volumeMax);
				setMuted(muted);

			elseif(response == "MUOFF") then	--mute off
				muted = 0;
				setStatus("Denon AVR-3806 ok, volume " .. currentVolume());
				setVolume(volume / volumeMax);
				setMuted(muted);

			elseif(response:sub(1, 2) == "MV") then		--master volume report
				
				if(response:sub(3, 5) == "MAX") then	--master volume max report
					
					reportedVolumeMax = parseVolumeLevel(response:sub(7));
					
					if((reportedVolumeMax ~= volumeMax) and (reportedVolumeMax > 0)) then
						volumeMax = reportedVolumeMax;
					end
					
					setStatus("Denon AVR-3806 ok, volume " .. currentVolume());
					setVolume(volume / volumeMax);

				else
					
					reportedVolume = parseVolumeLevel(response:sub(3));

					if((reportedVolume ~= nil) and (reportedVolume > 0) and (reportedVolume < 100)) then
						volume = reportedVolume;
						
						if(volumeMax > 0) then
							setStatus("Denon AVR-3806 ok, volume " .. currentVolume());
							setVolume(volume / volumeMax);
						else
							print("don't know max volume");
						end
					end

				end
			
			elseif(response:sub(1, 2) == "PW") then

				if(response:sub(3, 5) == "ON") then

					initialized = true;
					serialWrite("MV?\r");	--seed volume data by querying it

				elseif(response:sub(3, 10) == "STANDBY") then
				
					if(not initialized) then
						initialized = true;
						serialWrite("PWON\r");
						setStatus("Denon AVR-3806 powering on.");
					else
						setStatus("Denon AVR-3806 off.");
					end

				end
			
			end

		end

	elseif(event == "volume") then
		if(value > 1) then
			value = 1;
		end
		if(value < 0) then
			value = 0;
		end
		--if(volumeMax > 0) then
			serialWrite("MV" .. formatVolume(volumeMax * value) .. "\r");
		--end

	elseif(event == "mute") then
		print("muted = " .. tostring(muted) .. ", value = " .. tostring(value));
		if(value == 1) then
			serialWrite("MUON\r");
		else
			serialWrite("MUOFF\r");
		end

	elseif(event == "power") then

		if(value == "wake") then

			serialWrite("PWON\r");

		elseif(value == "sleep") then

			serialWrite("PWSTANDBY\r");

		end

	else
		print("Unhandled event", event, value);

	end

end

--initialize here
setSerialBaud(9600);
init();
