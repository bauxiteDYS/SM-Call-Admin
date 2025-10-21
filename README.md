# SM-Call-Admin
Sourcemod plugin that can call a Server Admin on Discord  

**Notes**
- Not fully complete but works, some values are hardcoded instead of being read from config file
- You must add these values before compiling as they are **NOT meant to be shared** (webhook, thread and role IDs)
- It will put the message into a thread under the channel associated with the webhook
- Players get 1 admin request per map, total requests 3 per map  
- Meant to be used for tournaments and such idk

**Requirements**  
- https://github.com/Sarrus1/DiscordWebhookAPI
