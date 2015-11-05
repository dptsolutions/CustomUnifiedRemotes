-- AV System Remote

-- Config
local UUIRTDRV_CFG_LEDRX		= 0x0001
local UUIRTDRV_CFG_LEDTX		= 0x0002
local UUIRTDRV_CFG_LEGACYRX		= 0x0004

-- Format
local UUIRTDRV_IRFMT_UUIRT		= 0x0000
local UUIRTDRV_IRFMT_PRONTO		= 0x0010

-- Friendly Format
local FORMAT_UUIRT 		= "uuirt";
local FORMAT_PRONTO 	= "pronto";

-- Learn
local UUIRTDRV_IRFMT_LEARN_FORCERAW		= 0x0100
local UUIRTDRV_IRFMT_LEARN_FORCESTRUC	= 0x0200
local UUIRTDRV_IRFMT_LEARN_FORCEFREQ	= 0x0400
local UUIRTDRV_IRFMT_LEARN_FREQDETECT	= 0x0800

-- Error
local UUIRTDRV_ERR_NO_DEVICE = 0x20000001
local UUIRTDRV_ERR_NO_RESP   = 0x20000002
local UUIRTDRV_ERR_NO_DLL    = 0x20000003
local UUIRTDRV_ERR_VERSION   = 0x20000004

-- UsbUirt Lib
local ffi = require("ffi");
ffi.cdef[[
	//typedef void (WINAPI *PUUCALLBACKPROC) (char *IREventStr, void *userData);
	//typedef void (WINAPI *PLEARNCALLBACKPROC) (unsigned int progress, unsigned int sigQuality, unsigned long carrierFreq, void *userData);
	typedef void* HUUHANDLE;
	typedef void *HANDLE;
	typedef struct {
		unsigned int fwVersion;
		unsigned int protVersion;
		unsigned char fwDateDay;
		unsigned char fwDateMonth;
		unsigned char fwDateYear;
	} UUINFO, *PUUINFO;
	HUUHANDLE UUIRTOpen(void);
	bool 	UUIRTClose(HUUHANDLE hHandle);
	bool 	UUIRTGetDrvInfo(unsigned int *puDrvVersion);
	bool 	UUIRTGetUUIRTInfo(HUUHANDLE hHandle, PUUINFO puuInfo);
	bool	UUIRTGetUUIRTConfig(HUUHANDLE hHandle, unsigned int* puConfig);
	bool 	UUIRTSetUUIRTConfig(HUUHANDLE hHandle, unsigned int uConfig);
	bool 	UUIRTTransmitIR(HUUHANDLE hHandle, char *IRCode, int codeFormat, int repeatCount, int inactivityWaitTime, HANDLE hEvent, void *reserved0, void *reserved1);
	bool	UUIRTLearnIR(HUUHANDLE hHandle, int codeFormat, char *IRCode, void *progressProc, void *userData, bool *pAbort, unsigned int param1, void *reserved0, void *reserved1);
	//bool	UUIRTSetReceiveCallback(HUUHANDLE hHandle, PUUCALLBACKPROC receiveProc, void *userData);
]]
local lib = ffi.load("uuirtdrv");
local server = libs.server;

state = {}

events.focus = function ()
	local handle = lib.UUIRTOpen();
	state.handle = handle;
	
	local code = ffi.new("char[2048]", 0);
	state.code = code;
	
	local abort = ffi.new("bool[1]", 0);	
	state.abort = abort;
	
	status(
		"For learning, make sure to hold your remote control approximately 5 cm from the USB-UIRT module.\n\n" ..
		"Press Learn button to begin learning. Hold the button your remote control until the code appears.\n\n" ..
		"Press Transmit to test that the code works. Copy/use the code in a custom remote or a widget.\n\n" ..
		"For more info, please visit:\nwww.unifiedremote.com/guides"
	);
end

events.blur = function ()
	local close = lib.UUIRTClose(state.handle);
end

function status(s)
	server.update({ id = "status", text = s });
end

actions.learn = function (fmt)
	status("Learning...");
	
	local f = UUIRTDRV_IRFMT_PRONTO;
	if (fmt == FORMAT_UUIRT) then
		f = UUIRTDRV_IRFMT_UUIRT;
	end
	
	local learn = lib.UUIRTLearnIR(state.handle,
		bit.bor(f, UUIRTDRV_IRFMT_LEARN_FORCERAW), -- codeFormat
		state.code,		--IRCode
		nil,			--progressProc callback
		nil,			--userData
		state.abort,	--pAbort
		0,				--forced frequency
		nil,nil			--reserved
	);
	
	if (learn) then
		status(ffi.string(state.code));
		server.set("code", ffi.string(state.code));
	else
		status("Error");
	end
end

actions.transmit = function (fmt,code)
	status("Transmitting...");
	
	local f = UUIRTDRV_IRFMT_PRONTO;
	if (fmt == FORMAT_UUIRT) then
		f = UUIRTDRV_IRFMT_UUIRT;
	end
	
	if (code ~= nil) then
		state.code = ffi.new("char[2048]", code);
	end
	
	local tx = lib.UUIRTTransmitIR(state.handle,
		state.code, --IRCode
		bit.bor(f, UUIRTDRV_IRFMT_LEARN_FORCERAW), -- codeFormat
		1,	--repeatCount,
		100,	--inactivityWaitTime
		nil,	--hEvent
		nil,nil	--reserved
	);
	
	if (tx) then
		status(ffi.string(state.code));
	else
		status("Error");
	end
end

------------
--TV Codes
------------
local CODE_SAMSUNG_POWER	 = "0000 006d 0022 0003 00a9 00a8 0015 003f 0015 003f 0015 003f 0015 0015 0015 0015 0015 0015 0015 0015 0015 0015 0015 003f 0015 003f 0015 003f 0015 0015 0015 0015 0015 0015 0015 0015 0015 0015 0015 0015 0015 003f 0015 0015 0015 0015 0015 0015 0015 0015 0015 0015 0015 0015 0015 0040 0015 0015 0015 003f 0015 003f 0015 003f 0015 003f 0015 003f 0015 003f 0015 0702 00a9 00a8 0015 0015 0015 0e6e";
local CODE_SAMSUNG_VOL_UP	 = "F42R03A480AA80AA163F163F163F16151615161516151614163F163F163F16151615161516151614163F163F163F16151615161516151615161516151615163F163F163F163F163F16";
local CODE_SAMSUNG_VOL_DOWN	 = "F42R03A480AB80AB1640163F1640161516151615161516141640163F1640161516151615161516141640163F1615163F161516151615161516151614164016141640163F1640163F16";
local CODE_SAMSUNG_MUTE		 = "F41R03A480AB80AB1640163F1640161516151615161516151640163F1640161516151615161516151640163F16401640161516151615161516151615161516151640163F1640163F16";
local CODE_SAMSUNG_SOURCE	 = "F42R03A480AB80AB163F163F164016151615161516151614163F163F164016151615161516151614164016151615161516151615161516151615163F1640163F1640163F163F163F16"
local CODE_SAMSUNG_CHAN_UP	 = "F42R03A480AB80AA163F163F164016151615161516151614163F163F1640161516151615161516151615163F16151614164016151615161416401614163F163F1615163F163F163F16"
local CODE_SAMSUNG_CHAN_DOWN = "F42R03A480AB80AA163F163F164016151615161516151614163F163F16401615161516151615161516151615161516141640161516151614163F163F163F163F1615163F163F163F16"

------------
--TV Actions
------------
actions.tv_power = function ()
	actions.transmit(FORMAT_PRONTO, CODE_SAMSUNG_POWER);
end

actions.tv_vol_up = function ()
	actions.transmit(FORMAT_UUIRT, CODE_SAMSUNG_VOL_UP);
end

actions.tv_vol_down = function ()
	actions.transmit(FORMAT_UUIRT, CODE_SAMSUNG_VOL_DOWN);
end

actions.tv_mute = function ()
	actions.transmit(FORMAT_UUIRT, CODE_SAMSUNG_MUTE);
end

actions.tv_source = function ()
	actions.transmit(FORMAT_UUIRT, CODE_SAMSUNG_SOURCE);
end

actions.tv_chan_up = function ()
	actions.transmit(FORMAT_UUIRT, CODE_SAMSUNG_CHAN_UP);
end

actions.tv_chan_down = function ()
	actions.transmit(FORMAT_UUIRT, CODE_SAMSUNG_CHAN_DOWN);
end

---------------
--Pioneer Codes
---------------
local CODE_VSX1018AH_POWER		= "F3ER01F3815880AC1640161616401616161616401616164016161640161616401640161616401616161616161640164016401616161616161640164016161616161616401640164016";
local CODE_VSX1018AH_VOL_UP		= "F3ER01F3815880AC1640161616401616161616401616164016161640161616401640161616401616161616401616164016161616161616161640161616401616164016401640164016";
local CODE_VSX1018AH_VOL_DOWN	= "F3ER01F3815880AC1640161616401616161616401616164016161640161616401640161616401616164016401616164016161616161616161616161616401616164016401640164016";
local CODE_VSX1018AH_MUTE		= "F3ER01F3815880AC1640161616401616161616401616164016161640161616401640161616401616161616401616161616401616161616161640161616401640161616401640164016";
local CODE_VSX1018AH_BD			= "F3ER01F4815880AC16401616164016161616164016161640161616401616164016401616164016161616161616401640164016161640161616401640161616161616164016161640168408815880AB1640161616401616161616401616164016161640161616401640161616401616161616161616161616161616164016401640164016401640164016401616161616"
local CODE_VSX1018AH_TV			= "F3ER01F4815780AB1640161516401615161516401615164016151640161516401640161516401615161516151640164016151615161516151640164016151615164016401640164016"
local CODE_VSX1018AH_HDMI		= "F3ER01F4815780AB16401615164016151615164016151640161516401615164016401615164016151615164016401615164016151640161516401615161516401615164016151640168408815780AB1640161516401615161516401615164016151640161516401640161516401615161516401615161516151615164016401640161516401640164016401615161516"
local CODE_VSX1018AH_DVD		= "F3ER01F4815780AB1640161516401615161516401615164016151640161516401640161516401615164016151640161516151615161516401615164016151640164016401640161516"

-----------------
--Pioneer Actions
-----------------
actions.receiver_power = function ()
	actions.transmit(FORMAT_UUIRT, CODE_VSX1018AH_POWER);
end

actions.receiver_vol_up = function ()
	actions.transmit(FORMAT_UUIRT, CODE_VSX1018AH_VOL_UP);
end

actions.receiver_vol_down = function ()
	actions.transmit(FORMAT_UUIRT, CODE_VSX1018AH_VOL_DOWN);
end

actions.receiver_mute = function ()
	actions.transmit(FORMAT_UUIRT, CODE_VSX1018AH_MUTE);
end

actions.receiver_bd = function ()
	actions.transmit(FORMAT_UUIRT, CODE_VSX1018AH_BD);
end

actions.receiver_tv = function ()
	actions.transmit(FORMAT_UUIRT, CODE_VSX1018AH_TV);
end

actions.receiver_hdmi = function ()
	actions.transmit(FORMAT_UUIRT, CODE_VSX1018AH_HDMI);
end

actions.receiver_dvd = function ()
	actions.transmit(FORMAT_UUIRT, CODE_VSX1018AH_DVD);
end