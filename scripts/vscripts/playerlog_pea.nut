::PLAYERLOG <-
{
	InitLog = function() { StringToFile(logname + "0", "") }

	ProgressLog = function(grantall = false) // remember to declare wavecount variable in the mission's nut file!
	{
		local std =
		{
			[48] = 0,
			[49] = 1,
			[50] = 2
		}

		local basewavestatus = ""

		for (local i = 1; i <= wavecount; i++) basewavestatus += "0"

		local fileid
		local playerlog

		for (local i = 0; i <= 100; i++)
		{
			fileid = i

			playerlog = FileToString(logname + i)

			if (playerlog == null)
			{
				playerlog = ""
				break
			}

			if (playerlog.len() >= playerlog_limit) continue
			else break
		}

		for (local i = 1; i <= MaxClients().tointeger(); i++)
		{
			local player = PlayerInstanceFromIndex(i)

			if (player == null) continue
			if (player.GetTeam() != 2) continue
			if (player.IsFakeClient()) continue

			local compile = ""
			local wavestatus
			local waveprogress = ""

			local logdata = IsInLog.call(player.GetScriptScope())

			if (grantall) wavestatus = "222222"
			else
			{
				if (logdata.found) wavestatus = logdata.wavedata

				else wavestatus = basewavestatus
			}

			for (local g = 0; g <= wavestatus.len() - 1; g++)
			{
				if (Wave == secretwave && g == (secretwave - 1) && !secretwave_unlocked)
				{
					waveprogress += std[wavestatus[g]]
					continue
				}

				if ((Wave - 1) != g) waveprogress += std[wavestatus[g]]

				else
				{
					if (std[wavestatus[g]] == 2)
					{
						waveprogress += std[wavestatus[g]]
						continue
					}

					if (wavewon)
					{
						if (std[wavestatus[g]] >= 1) waveprogress += 2
						else						 waveprogress += 0
					}

					else waveprogress += 1
				}
			}

			compile += logdata.userid + "|" + waveprogress + " "

			if (!logdata.found) playerlog += compile
			else
			{
				if (logdata.logid == fileid) playerlog = playerlog.slice(0, logdata.fulldata_start) + compile + playerlog.slice(logdata.fulldata_end)
				else
				{
					local searchlog = FileToString(logname + logdata.logid)
					searchlog = searchlog.slice(0, logdata.fulldata_start) + compile + searchlog.slice(logdata.fulldata_end)
					StringToFile(logname + logdata.logid, searchlog)
				}
			}
		}

		StringToFile(logname + fileid, playerlog)
	}

	IsInLog = function()
	{
		local resulttable =
		{
			found = false
			userid = null
			logid = null
			fulldata_start = null
			fulldata_end = null
			wavedata = null
			completedall = false
		}

		local id = NetProps.GetPropString(self, "m_szNetworkIDString")

		resulttable.userid = id.slice(5, id.find("]"))

		local searchlog
		local searchfileid

		for (local j = 0; j <= 100; j++)
		{
			searchlog = FileToString(logname + j)
			searchfileid = j

			if (searchlog == null) return resulttable

			local slot = searchlog.find(resulttable.userid)

			if (slot != null)
			{
				local wavedata_start = searchlog.find("|", slot)
				local wavedata_end = searchlog.find(" ", slot)

				resulttable.found = true
				resulttable.logid = j
				resulttable.fulldata_start = slot
				resulttable.fulldata_end = wavedata_end + 1
				resulttable.wavedata = searchlog.slice(wavedata_start + 1, wavedata_end)

				if (resulttable.wavedata.find("0") == null && resulttable.wavedata.find("1") == null) resulttable.completedall = true

				return resulttable
			}
		}

		return resulttable
	}

	AddToLog = function()
	{
		local basewavestatus = ""

		for (local i = 1; i <= wavecount; i++) basewavestatus += "0"

		local id = NetProps.GetPropString(self, "m_szNetworkIDString")
		local idproper = id.slice(5, id.find("]"))

		local fileid
		local playerlog

		for (local i = 0; i <= 100; i++)
		{
			fileid = i

			playerlog = FileToString(logname + i)

			if (playerlog == null)
			{
				playerlog = ""
				break
			}

			if (playerlog.len() >= playerlog_limit) continue
			else break
		}

		playerlog += idproper + "|" + basewavestatus + " "

		StringToFile(logname + fileid, playerlog)
	}

	LogWipe = function()
	{
		for (local j = 0; j <= 100; j++)
		{
			local log = FileToString(logname + j)

			if (log == null) break

			StringToFile(logname + j, "")
		}
	}
}