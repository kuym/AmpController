print("Denon");

function init()
	muted = false;
	buffer = "";
	volume = 0;
	volumeMax = 0;
	volumeStep = 3;
end

function parseVolumeLevel(str)

	v = tonumber(str);
	
	if(v >= 100) then
		return(v / 10);
	else
		return(v);
	end
end

function currentVolume()
	percentStr = tostring(math.floor(100 * volume / volumeMax)) .. "%";
	
	if(muted) then
		return("muted " .. percentStr);
	else
		return(percentStr);
	end
end

function formatVolume(value)
	return(tostring(math.floor(value)));
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
			serialWrite("MV" .. formatVolume(volume + volumeStep) .. "\r");

		elseif(value == 12) then	--toggle mute
			print("mute key");
			if(muted) then
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
		offset = string.find(buffer, "\r");

		if(offset ~= nil) then

			response = string.sub(buffer, 1, offset - 1);
			buffer = string.sub(buffer, offset + 1);

			print("Denon response:", response);
			
			if(response == "MUON") then		--mute on
				muted = true;
				setStatus("Denon AVR-3806 ok, volume " .. currentVolume());

			elseif(response == "MUOFF") then	--mute off
				muted = false;
				setStatus("Denon AVR-3806 ok, volume " .. currentVolume());

			elseif(string.sub(response, 1, 2) == "MV") then		--master volume report
				
				if(string.sub(response, 3, 5) == "MAX") then	--master volume max report
					
					reportedVolumeMax = parseVolumeLevel(string.sub(response, 6));
					
					if(reportedVolumeMax ~= volumeMax) then
						volumeMax = reportedVolumeMax;
						setStatus("Denon AVR-3806 ok, volume " .. currentVolume());
					end

				else
					
					reportedVolume = parseVolumeLevel(string.sub(response, 3));

					if((reportedVolume ~= nil) and (reportedVolume > 0) and (reportedVolume < 100)) then
						volume = reportedVolume;
						
						setStatus("Denon AVR-3806 ok, volume " .. currentVolume());
					end

				end
			end

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
init();
setSerialBaud(9600);

serialWrite("MV?\r");	--seed volume data by querying it

setStatus("Denon AVR-3806 pending.");
