#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <discordWebhookAPI>

#define DEBUG false

#define ROLE true

StringMap g_allJoinerData = null;

enum struct joinerData {
	float joinTime;
	bool doneCall;
}

char g_clientSteamID[MAXPLAYERS+1][32];
int g_totalCalls;

float g_lastCallAttempt[MAXPLAYERS+1];
char g_tag[] = "[Admin Call]";

//hardcoded for now DO NOT SHARE PUBLICLY
char g_webhook[] = 
	"[add]";

//hardcoded for now DO NOT SHARE PUBLICLY
char g_threadID[] = "[add]";

//hardcoded for now DO NOT SHARE PUBLICLY
//switch ROLE to false if you want to ping a single user instead of a role
#if ROLE
char g_roleID[] = "[add]";
#else
char g_userID[] = "[add]";
#endif

char g_steamurl[] = "[ID](<https://steamcommunity.com/profiles/%s>)";

public Plugin myinfo = {
	name = "Call Admin on Discord for NT Tournaments",
	description = "Allows players to !calladmin",
	author = "bauxite",
	version = "0.1.0",
	url = "www.baux.site",
};

public void OnPluginStart()
{
	g_allJoinerData = new StringMap();
	
	RegConsoleCmd("sm_calladmin", CallAdmin, "Notify an admin");
}

void ResetVariables()
{
	g_allJoinerData.Clear();
	g_totalCalls = 0;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		g_clientSteamID[i][0] = '\0';
		g_lastCallAttempt[i] = 0.0;
	}
}

public void OnMapEnd()
{
	ResetVariables();
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if(!GetClientAuthId(client, AuthId_SteamID64, g_clientSteamID[client], sizeof(g_clientSteamID[])))
	{
		return;
	}
	
	joinerData data;
	
	data.joinTime = GetGameTime();
	data.doneCall = false;

	g_allJoinerData.SetArray(g_clientSteamID[client], data, sizeof(data), false);
	
	#if DEBUG
	PrintToServer("steamid auth:%s:", g_clientSteamID[client]);
	#endif
}

public Action CallAdmin(int client, int args)
{
	if(client <= 0)
	{
		return Plugin_Continue;
	}
	
	if(args < 1)
	{
		ReplyToCommand(client, "%s Usage: !calladmin <reason>", g_tag);
		return Plugin_Handled;
	}
	
	float curTime = GetGameTime();
	
	if(curTime < g_lastCallAttempt[client] + 15.0)
	{
		ReplyToCommand(client, "%s You can only try this command once every 15s, 15s after map start", g_tag);
		return Plugin_Handled;
	}
	
	g_lastCallAttempt[client] = curTime;
	
	joinerData data;
	
	if(!g_allJoinerData.GetArray(g_clientSteamID[client], data, sizeof(data)))
	{
		ReplyToCommand(client, "%s Failed to call Admin, try again later", g_tag);
		return Plugin_Handled;
	}
	
	#if DEBUG
	PrintToServer("sizeof:%d:", sizeof(data));
	PrintToServer("jointime:%f:", data.joinTime);
	PrintToServer("called:%s:", data.doneCall ? "yes" : "no");
	#endif
	
	#if DEBUG
	if(curTime < data.joinTime + 30.0)
	#else
	if(curTime < data.joinTime + 60.0)
	#endif
	{
		ReplyToCommand(client, "%s You can only call an admin if you joined the server at least 1 minute ago", g_tag);
		return Plugin_Handled;
	}
	
	if(data.doneCall || g_totalCalls > 3)
	{
		ReplyToCommand(client, "%s You can only call an admin once every map, with a total of 3 times per map between all players", g_tag);
		return Plugin_Handled;
	}
	
	data.doneCall = true;
	
	g_allJoinerData.SetArray(g_clientSteamID[client], data, sizeof(data), true);
	
	g_totalCalls++;
	
	char buf[57+71+24+64+128+1];
	char reason[128];
	char name[32];
	char clienturl[71];
	char serverName[64];
	
	FindConVar("hostname").GetString(serverName, sizeof(serverName));
	if(strlen(serverName) != 0)
	{
		ReplaceString(serverName, sizeof(serverName), "`", "ˋ", false);
	}
	else
	{
	 strcopy(serverName, sizeof(serverName), "[UNKNOWN]");
	}
	
	if(GetCmdArgString(reason, sizeof(reason)) != 0)
	{
		// replace backticks (Grave Accent U+0060) with (Modifier Grave Accent U+02CB)
		ReplaceString(reason, sizeof(reason), "`", "ˋ", false);
	}
	else
	{
		strcopy(reason, sizeof(reason), "[UNKNOWN]");
	}
	
	if(GetClientName(client, name, sizeof(name)) && strlen(name) != 0)
	{
		ReplaceString(name, sizeof(name), "`", "ˋ", false);
	}
	else
	{
		strcopy(reason, sizeof(reason), "[UNKNOWN]");
	}
	
	Format(clienturl, sizeof(clienturl), g_steamurl, g_clientSteamID[client]);
	
	#if ROLE
	Format(buf, sizeof(buf), "[%s] Needs a server admin <@&%s> Server: `%s`. Reason: `%s`", clienturl, g_roleID, serverName, reason);
	#else
	Format(buf, sizeof(buf), "[%s] Needs a server admin <@%s> Server: `%s`. Reason: `%s`", clienturl, g_userID, serverName, reason);
	#endif
	
	Webhook adminMessage = new Webhook(buf);
	adminMessage.SetUsername(name);

	if (g_webhook[0] == '\0')
	{
		LogError("The webhook URL of your Discord channel was not found or specified.");
		PrintToChat(client, "%s Error: Your message could not be delivered", g_ctag);
		delete adminMessage;
		return Plugin_Handled;
	}
	
	int userid = GetClientUserId(client);
	
	adminMessage.Execute(g_webhook, OnWebHookExecuted, userid, g_threadID); // ThreadID is optional
	delete adminMessage;

	return Plugin_Handled;
}

public void OnWebHookExecuted(HTTPResponse response, int userid)
{
	int client = GetClientOfUserId(userid);
	bool success;
	
	if(response.Status != HTTPStatus_OK && response.Status != HTTPStatus_NoContent)
	{
		LogError("An error has occured while sending the webhook.");
	}
	else
	{
		success = true;
	}
	
	if(client <= 0 || !IsClientInGame(client))
	{
		return;
	}
	
	if(success)
	{
		PrintToChat(client, "%s Your message was succesfully sent to an admin", g_tag);
	}
	else
	{
		PrintToChat(client, "%s Error: Your message could not be delivered", g_tag);
	}
}
