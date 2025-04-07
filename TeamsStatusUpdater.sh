#!/bin/bash
##############
# TENANT AZURE: sul tenant Azure deve essere stata registrata una APP , es Calendar API Reader
# TENANT AZURE: URL di reindirizzamento: https://login.microsoftonline.com/common/oauth2/nativeclient & http://localhost
# TENANT AZURE: Creare un Client Secret, segnarsi ClientID e ClientSec
# TANANT AZURE: Autorizzazioni per Microsoft Graph di tipo Appliczione e Delagato per: Application.Read.All/Calendars.Read/User.Read.All/Group.Real.All/Presence.Read.All - Concedere Accesso Amministrativo
###############
#Editare con i dati del centralino
WAPIuser='admin'
WAPIpsw='password'
WPBX='127.0.0.1'
###############
# Settare le variabili ottenute creando la APP su Tenant
TenantID="dasdasdas"
ClientID="aasaad"
ClientSec="sdadas"
# Gruppo AzureAD degli utenti teams/wildix
GROUP_XBEES="id_del_gruppo"
###############
#URL Autenticazione per le API
URLGetToken='https://login.microsoftonline.com/'$TenantID'/oauth2/v2.0/token'
#Ottengo token di autenticazione, di durata 3600 secondi standard
ACCESS_TOKEN=$(curl -s --location --request POST $URLGetToken --header 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'client_id='$ClientID --data-urlencode 'scope=https://graph.microsoft.com/.default' --data-urlencode 'client_secret='$ClientSec --data-urlencode 'grant_type=client_credentials'  | jq -r '.access_token')

#echo $ACCESS_TOKEN
########## RICHIESTA
# Url base ALL USER
GRAPH_URL_base='https://graph.microsoft.com/beta/users'
GRAPH_URL_group='https://graph.microsoft.com/beta/groups/'$GROUP_XBEES'/members'

# Url base GROUP USER
# Lista Utenti
users_response=$(curl -s -X GET "$GRAPH_URL_group" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json")

# Estrai Used ID:

user_ids=$(echo "$users_response" | jq -r '.value[].id')
#echo $user_ids

# Presenza per ogni utente
for user_id in $user_ids; do
WildixNumber="99999"
	teams_status_message=$(curl -s -X GET "$GRAPH_URL_base/$user_id/presence" \
	-H "Authorization: Bearer $ACCESS_TOKEN" \
	-H "Content-Type: application/json" \
	| jq -r '.statusMessage.message.content | gsub("<p>|</p>"; "")')

	echo "Presence for user $user_id:"
	echo $teams_status_message

	WildixNumber=$(curl -s -X GET "$GRAPH_URL_base/$user_id" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
	| jq -r '.preferredLanguage' ) # o usare un altro campo per ottenere il numero di telefono
	echo "Wildix Number"
	echo $WildixNumber

# SET WILDIX MESSAGE STATUS 

current_status=$(curl -s -X GET -u $WAPIuser:$WAPIpsw 'http://'$WPBX'/api/v1/User/'$WildixNumber'/Presence' | jq -r '.result.show')
#Se è vuoto, sarà available
if [ -z "$current_status" ]; then
        current_status="available"
        echo $current_status
else
        echo $current_status
fi
curl -X PUT -u $WAPIuser:$WAPIpsw 'http://127.0.0.1/api/v1/User/'$WildixNumber'/Presence' \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data '{
    "status": "'"$current_status"'",
    "message": "'"$teams_status_message"'" 
 }'
done
