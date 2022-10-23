# Renomme les services avec "MS Exchange" devant
get-service | where{$_.displayname -like "*Exchange*"} | Foreach{
$nomAffiche=$_.DisplayName
$nomAffiche=$nomAffiche.Replace("Microsoft Exchange","")
If($nomAffiche[0] -like " "){$nomAffiche=$nomAffiche.Substring(1)}
Set-service $_.name -displayname "Microsoft Exchange - $nomAffiche"
}

# Accès commandes PS Exchange
$ExchangeSession=New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "HTTP://echion.pasteur.nc/powershell/?serializationlevel=full" -ErrorAction stop
Import-PSSession $ExchangeSession -ErrorAction stop -WarningAction SilentlyContinue -DisableNameChecking | Out-Null

# Listes les BAL avec tailles
Get-Mailbox | Get-MailboxStatistics | Sort-Object -Descending -Property TotalItemSize | ft DisplayName, TotalItemSize, TotalDeletedItemSize

# Ajoute un groupe dédié à l'import "Exchange-Import" (créer d_abord dans l_AD)
New-ManagementRoleAssignment -Name "Import Export Mailbox Admins" -SecurityGroup "Exchange-Import" -Role "Mailbox Import Export"

#Déplacement DB (ConfigurationOnly : change seulement le chemin, ne déplace pas les fichiers)
Move-DatabasePath -Identity "MB DB SRV-1-2" -EdbFilePath "C:\ExchangeBDD\MB DB SRV-1-2\MB DB SRV-1-2.edb" -LogFolderPath "C:\ExchangeBDD" -ConfigurationOnly

#Export fichier PST
New-MailboxExportRequest -Mailbox elapouss -FilePath "\\srv-1.adatum.nc\Users\Administrateur.ADATUM\Desktop\exchange_install\Exchange_2013\Outils\erwan.pst"
Get-MailboxExportRequest

# Import fichier PST (doit être sur un chemin réseau)
New-MailboxImportRequest -Mailbox afort -FilePath "\\srv-1.adatum.nc\Users\Administrateur.ADATUM\Desktop\exchange_install\Exchange_2013\Outils\erwan.pst"
Get-MailboxImportRequest
Get-MailboxImportRequestStatistics -Identity afort\MailboxImport
# ou
Get-MailboxImportRequest | Get-MailboxImportRequestStatistics
Remove-MailboxImportRequest -Identity afort\MailboxImport

# Affiche les paramètres de la stratégie d'adresse de messagerie par défaut
Get-EmailAddressPolicy -Identity "Default Policy" | fl
# Modifie la stratégie d'adresse de messagerie par défaut avec valeur perso (1ère lettre prénom . nom)
Set-EmailAddressPolicy -Identity "Default Policy" -EnabledEmailAddressTemplates "SMTP:%1g.%s@adatum.nc"

# Liste les utilisateurs AD n'ayant pas de BAL
get-user -RecipientTypeDetails "User"
# Récupère la liste des utilisateurs n'ayant pas de BAL et active leurs BALs
get-user | where{$_.recipienttype -eq "User"} | Enable-Mailbox

# Vérifier le partage par défaut des calendriers
Get-MailboxFolderPermission -identity scanard:\calendrier

Get-Mailbox -Identity scanard | fl
# Modifier les adresses d'expédition (SMTP : adresse par défaut)
Set-Mailbox -Identity afort -EmailAddresses "SMTP:direction2@adatum.nc","smtp:A.FORT@adatum.nc" -EmailAddressPolicyEnabled $false

# Suppression boîte mail
Get-Mailbox -Identity afort | fl
# Récupérer LecacyExchangeDN     /o=ADATUM/ou=Exchange Administrative Group (FYDIBOHF23SPDLT)/cn=Recipients/cn=9c427a2963cf49cd9903f46236e6f2fc-Alain FORT
# Si la personne revient ou que l'adresse esr réattribuée, pour éviter les problèmes de cache Outlook client lourd, ajouter l'adresse X500 relevée précédement.
# Exporter les emails si besoin (voir #Export fichier PST)
Disable-Mailbox -Identity afort

Get-CalendarProcessing -Identity bibliotheque | fl
Set-CalendarProcessing -Identity bibliotheque -BookInPolicy "afort","elapouss" -RequestOutOfPolicy "afort","elapouss" 

# Liste des carnets hors-connexion
Get-OfflineAddressBook | fl
# Modifie la liste des carnets hors-connexion
Set-OfflineAddressBook -Identity "\Carnet d'adresses en mode hors connexion par défaut" -AddressLists "\Liste d'adresses globale par défaut","\Tous les utilisateurs\DSI","\Tous les utilisateurs\Direction"
# Mise à jour des carnets hors-connexion
Get-OfflineAddressBook | Update-OfflineAddressBook

# Active le carnet hiérarchique
Get-OrganizationConfig
Set-OrganizationConfig -HierarchicalAddressBookRoot "Adatum"
# A passer pour le groupe racine et chaque sous-groupe :
Set-Group -Identity "Communication" -IsHierarchicalGroup $true

# Vérifier l'affinité de serveur
Get-ClientAccessService | fl Autodiscove*
# Changer l'URI
Get-ClientAccessService | Set-ClientAccessServer -AutoDiscoverServiceInternalUri "https://excas.adatum.nc/Autodiscover/Autodiscover.xml"

# Modification du nom du certificat sur les clients
Get-OutlookProvider | fl *
Get-OutlookProvider | Set-OutlookProvider -CertPrincipalName "excas.adatum.nc"

# Changer la langue pour toutes les boîtes
#Webmail
Get-MailBox | Set-Mailbox-Languages "fr-FR"
#Nom des dossiers
Get-MailBox | Set-MailboxRegionalConfiguration -Language fr-FR -LocalizeDefaultFolderName:$true

# Informations (envoi externe, grand nombre de destinataires, information)
Get-OrganizationConfig | fl *tip*
Set-OrganizationConfig -MailTipsLargeAudienceThreshold 10

# Application d'une stratégie OWA aux utilisateurs du service DSI
Get-User -filter {Department -eq "DSI"} | set-casmailbox -OwaMailboxPolicy DSI
Get-User -filter {Department -eq "DSI"} | get-casmailbox | fl *policy*

# Configuration de WebReady pour imposer l'enregistrement des .doc et .xls, ouverture directe des .pdf, interdire l'ouverture des .exe
Get-OwaMailboxPolicy | select -expandproperty forcesavefiletypes
Get-OwaMailboxPolicy | select -expandproperty WebReadyFileTypes
Set-OwaMailboxPolicy -Identity DSI -WebReadyFileTypes @{Remove=".exe"}
Set-OwaMailboxPolicy -Identity DSI -ForceSaveFileTypes @{Add=".doc"}
Set-OwaMailboxPolicy -Identity DSI -ForceSaveFileTypes @{Add=".xls"}
Set-OwaMailboxPolicy -Identity DSI -ForceSaveFileTypes @{Remove=".pdf"}
Set-OwaMailboxPolicy -Identity DSI -WebReadyFileTypes @{Add=".pdf"}

# Affiche config OWA hors ligne
Get-OwaMailboxPolicy | fl allowofflineon
Get-OwaVirtualDirectory | fl allowofflineon

# Liste tous les appareils mobiles synchronisés
Get-MobileDevice | fl
Get-MobileDevice | select DeviceOS, UserDisplayName

# Etat du DAG
Get-MailboxServer

# Entrer témoin secondaire
Get-DatabaseAvailabilityGroup | fl
Set-DatabaseAvailabilityGroup -Identity DAGONE -AlternateWitnessServer "srv-2.adatum.nc"
Set-DatabaseAvailabilityGroup -Identity DAGONE -AlternateWitnessDirectory "C:\DAG"
# Mode DAG only
Set-DatabaseAvailabilityGroup -Identity DAGONE -DatacenterActivationMode "DAGONLY"

# Vérifie la réplication des BDD dans le DAG
Get-MailboxDatabaseCopyStatus -server hermes
Test-ReplicationHealth

# Créer une base de données de récupération, la monter et restaurer une BAL
New-MailboxDatabase -Name "Recover DB" -Server SRV-TWO -EDBFilePath "C:\BDD Exchange\Recover\Recoverdb.edb" -Logfolderpath "C:\BDD Exchange\Recover\Recover" -Recovery
Mount-Database "Recover DB"
Get-MailboxStatistics -Database "Recover DB"
New-MailboxRestoreRequest -SourceDatabase "Recover DB" -SourceStoreMailbox "Yves LEPETIT" -TargetMailbox "Yves LEPETIT"
Get-MailboxRestoreRequest
Get-MailboxRestoreRequest | Get-MailboxRestoreRequestStatistics

# Restauration de toutes les BAL
$accounts=Get-MailboxStatistics -Database "Recover DB" | Select-Object -ExpandProperty DisplayName
Foreach($account in $accounts){
    New-MailboxRestoreRequest -SourceDatabase "Recover DB" -SourceStoreMailbox "$account" -TargetMailbox "$account"
    }


# Config serveur sur la taille des mails
Get-TransportConfig | fl *max*
Set-TransportConfig -MaxReceiveSize "20 MB" -MaxSendSize "20 MB" -ExternalDsnMaxMessageAttachSize "20 MB" -InternalDsnMaxMessageAttachSize "20 MB"

# Autorise relais SMTP anonyme sur le connecteur
Get-ReceiveConnector "Relais_DSI" | Add-ADPermission -User "ANONYMOUS LOGON" -ExtendedRights "Ms-Exch-SMTP-Accept-Any-Recipient"

# Désactive le format RTF en externe
Get-RemoteDomain | fl *TNEF*
Get-RemoteDomain | Set-RemoteDomain -TNEFEnabled $false

# Modifie la règle pour passer du responsable désigné manuellement au responsable AD
Get-TransportRule -Identity "Règle_PTT" | fl Moderate*
Set-TransportRule -Identity "Règle_PTT" -ModerateMessageByManager $true -ModerateMessageByUser $null


# Agents activés
Get-TransportAgent


# Vérifie les files d'attente
Get-TransportService | Get-Queue

# Enlève smtp anonyme, marchait 2013 cu5, plus maintenant
Get-ReceiveConnector "SRV-One.adatum.nc\Default Frontend SRV-ONE" | Get-ADPermission -User "AUTORITE NT\ANONYMOUS LOGON" | where {$_.ExtendedRights -like "ms-Exch-SMTP-Accept-Authoritative-Domain-Sender"} | Remove-ADPermission

# Défini l'adresse de postmaster externe et interne
Get-TransportService
Get-TransportConfig | Set-TransportConfig -ExternalPostmasterAddress "no-reply@pasteur.nc"
Get-TransportConfig | fl *postmaster*
Get-OrganizationConfig | fl *replyrecipient*
Set-OrganizationConfig -MicrosoftExchangeRecipientReplyRecipient "no-reply@pasteur.nc"

#Traces des messages
Get-MessageTrackingLog -Recipients dieu@formation.nc -Server srv-1

# Malware agent
Get-TransportAgent
Get-MalwareFilterPolicy | fl *
Get-MalwareFilterRule | fl *
get-help Set-MalwareFilterRule -Detailed
Get-MalwareFilteringServer | fl 

Get-Help Set-MalwareFilteringServer -Detailed
Set-MalwareFilteringServer -Identity hermes -SecondaryUpdatePath "zen.spamhaus.org"
# Modification du score de mise en quarantaine
get-OrganizationConfig | fl SCLJ*
Set-OrganizationConfig -SCLJunkThreshold 7
# Désactivation du filtrage en interne
Get-TransportConfig | fl *SMTP*
Set-TransportConfig -InternalSMTPServers @{Add="192.168.202.111"}
#Filtrage du contenu
Get-ContentFilterConfig | fl *
Set-ContentFilterConfig -SCLDeleteEnabled $true -SCLDeleteThreshold 9 -SCLRejectEnabled $false -SCLRejectThreshold 8 
get-help Add-ContentFilterPhrase -Detailed
get-help Get-ContentFilterPhrase -Detailed
Get-ContentFilterPhrase | fl *
Add-ContentFilterPhrase -Phrase "sexe" -Influence BadWord
Add-ContentFilterPhrase -Phrase "réunion" -Influence GoodWord

Get-SenderIdConfig | fl Enabled

# Créer une étendue de gestion
get-help New-ManagementScope -Detailed
New-ManagementScope -Name BoitesTech -RecipientRoot "adatum.nc/formateur/utilisateurs/technique" -RecipientRestrictionFilter {RecipientType -eq "UserMailbox"}
# Créer un nouveau rôle permettant la création mais pas la suppression à partir d'un rôle existant
New-ManagementRole -Name MRCreaOnly_tech -parent "Mail Recipient Creation"
Get-ManagementRoleEntry "MRCreaOnly_tech\*" | ?{$_.name -like "remove-*"} | Remove-ManagementRoleEntry -Confirm:$false
# Créer un groupe de rôles
New-RoleGroup -Name AdminBoitesTech -roles MRCreaOnly_tech -CustomRecipientWriteScope BoitesTech
# Ajouter un membre au groupe
Add-RoleGroupMember -Identity AdminBoitesTech -Member elapouss
# Voir tous les rôles existants
Get-ManagementRole
Get-ManagementRole -Identity MRCreaOnly_tech | fl

# Modifier le niveau de log
Get-AdminAuditLogConfig
Set-AdminAuditLogConfig -LogLevel Verbose

# Recherche des commandes de modification des connecteurs d'envoi
get-help Search-AdminAuditLog -Detailed
Search-AdminAuditLog | ft ObjectModified,CmdletName,CmdletParameters,ModifiedProperties,Caller

# Activer l'audit sur toutes les BAL
Get-Mailbox elapouss | fl *audit*
Get-Mailbox elapouss | select -ExpandProperty auditdelegate
Get-Mailbox | Set-Mailbox -AuditEnabled $true
Search-MailboxAuditLog -Mailboxes elapouss | fl *

# Passer Server en maintenance


Get-OwaVirtualDirectory -Server SRV-2 | Set-OwaVirtualDirectory -InternalUrl "https://excas.adatum.nc/owa" -ExternalUrl "https://excas.adatum.nc/owa"
