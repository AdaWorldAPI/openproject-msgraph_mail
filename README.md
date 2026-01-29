# OpenProject MS Graph Mail Modul

E-Mail-Versand über Microsoft Graph API anstelle von SMTP. Ideal für Microsoft 365 / Azure AD Umgebungen, in denen SMTP-Relay eingeschränkt ist.

## Funktionen

- 📧 E-Mail-Versand über Microsoft Graph API
- 🔐 Azure AD App-Registrierung Authentifizierung (Client Credentials Flow)
- 🎛️ Admin-Oberfläche für Konfiguration und Tests
- ✅ Verbindungstest und Test-E-Mails direkt aus dem Admin-Panel
- 🌐 Unterstützt alle OpenProject E-Mail-Benachrichtigungen

## Installation

### Option 1: Als Bundled Module (empfohlen)

Kopieren Sie den gesamten `modules/msgraph_mail` Ordner in Ihre OpenProject-Installation:

```bash
cd /path/to/openproject
cp -r /path/to/this/repo/* modules/msgraph_mail/
```

Fügen Sie das Modul zur `Gemfile.modules` hinzu:

```ruby
# Gemfile.modules
group :opf_plugins do
  gem 'openproject-msgraph_mail', path: 'modules/msgraph_mail'
end
```

Bundle installieren und neu starten:

```bash
bundle install
bundle exec rails db:migrate
bundle exec rails server
```

### Option 2: Als Git-Submodule

```bash
cd /path/to/openproject
git submodule add https://github.com/AdaWorldAPI/openproject-msgraph_mail.git modules/msgraph_mail
```

## Azure AD Einrichtung

### 1. App-Registrierung erstellen

1. Öffnen Sie das [Azure Portal → App-Registrierungen](https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationsListBlade)
2. Klicken Sie auf **Neue Registrierung**
3. Geben Sie einen Namen ein (z.B. "OpenProject Mail")
4. Wählen Sie "Nur Konten in diesem Organisationsverzeichnis"
5. Klicken Sie auf **Registrieren**

### 2. IDs notieren

Nach der Registrierung finden Sie auf der Übersichtsseite:
- **Anwendungs-ID (Client-ID)** → `MSGRAPH_CLIENT_ID`
- **Verzeichnis-ID (Mandanten-ID)** → `MSGRAPH_TENANT_ID`

### 3. Client-Geheimnis erstellen

1. Gehen Sie zu **Zertifikate & Geheimnisse**
2. Klicken Sie auf **Neues Clientgeheimnis**
3. Geben Sie eine Beschreibung ein und wählen Sie die Gültigkeitsdauer
4. Kopieren Sie den **Wert** (nicht die ID!) → `MSGRAPH_CLIENT_SECRET`

⚠️ **Wichtig:** Das Geheimnis wird nur einmal angezeigt!

### 4. API-Berechtigungen konfigurieren

1. Gehen Sie zu **API-Berechtigungen**
2. Klicken Sie auf **Berechtigung hinzufügen**
3. Wählen Sie **Microsoft Graph**
4. Wählen Sie **Anwendungsberechtigungen**
5. Suchen Sie nach **Mail.Send** und aktivieren Sie es
6. Klicken Sie auf **Berechtigungen hinzufügen**
7. Klicken Sie auf **Administratorzustimmung für [Ihr Mandant] erteilen**

### 5. Absender-Postfach

Der Absender (`MSGRAPH_SENDER_EMAIL`) muss ein gültiges Postfach sein:
- Ein Benutzerpostfach (z.B. `noreply@firma.de`)
- Ein freigegebenes Postfach (empfohlen)

## Konfiguration

### Umgebungsvariablen

Setzen Sie folgende Umgebungsvariablen in Ihrer OpenProject-Konfiguration:

```bash
# Erforderlich
MSGRAPH_TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
MSGRAPH_CLIENT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
MSGRAPH_CLIENT_SECRET=your-client-secret-value
MSGRAPH_SENDER_EMAIL=noreply@ihrefirma.de

# Optional
MSGRAPH_SENDER_NAME=OpenProject
MSGRAPH_SAVE_TO_SENT_ITEMS=true

# Auto-Aktivierung beim Start (optional)
EMAIL_DELIVERY_METHOD=msgraph
```

### Docker / Docker Compose

```yaml
# docker-compose.yml
services:
  openproject:
    environment:
      MSGRAPH_TENANT_ID: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      MSGRAPH_CLIENT_ID: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      MSGRAPH_CLIENT_SECRET: "your-client-secret-value"
      MSGRAPH_SENDER_EMAIL: "noreply@ihrefirma.de"
      EMAIL_DELIVERY_METHOD: "msgraph"
```

### Packaged Installation (DEB/RPM)

Bearbeiten Sie `/etc/openproject/conf.d/msgraph.conf`:

```bash
export MSGRAPH_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export MSGRAPH_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export MSGRAPH_CLIENT_SECRET="your-client-secret-value"
export MSGRAPH_SENDER_EMAIL="noreply@ihrefirma.de"
export EMAIL_DELIVERY_METHOD="msgraph"
```

Dann neu starten:

```bash
sudo openproject configure
sudo systemctl restart openproject
```

## Admin-Oberfläche

Nach der Installation finden Sie die Einstellungen unter:

```
Administration
└── E-Mails und Benachrichtigungen
    ├── Aggregation
    ├── E-Mail-Benachrichtigungen
    ├── MS Graph Mail              ← Hier
    └── Eingehende E-Mails
```

### Funktionen der Admin-Seite

| Button | Funktion |
|--------|----------|
| **Verbindung testen** | Prüft ob die Azure AD Zugangsdaten korrekt sind |
| **Test-E-Mail senden** | Sendet eine Test-E-Mail an den angemeldeten Admin |
| **MS Graph Mail aktivieren** | Aktiviert MS Graph als E-Mail-Zustellmethode |
| **Deaktivieren** | Wechselt zurück zu SMTP |

## Fehlerbehebung

### "Verbindung fehlgeschlagen"

- Prüfen Sie Tenant ID, Client ID und Client Secret
- Stellen Sie sicher, dass die App die `Mail.Send` Berechtigung hat
- Überprüfen Sie, ob die Administratorzustimmung erteilt wurde

### "Test-E-Mail konnte nicht gesendet werden"

- Der Absender muss ein gültiges Postfach in Microsoft 365 sein
- Das Postfach muss lizenziert und aktiv sein
- Die Azure AD App benötigt die Berechtigung für dieses Postfach

### Modul erscheint nicht im Admin-Menü

- Starten Sie OpenProject nach Konfigurationsänderungen neu
- Prüfen Sie die Rails-Logs auf Startfehler
- Stellen Sie sicher, dass das Modul in `Gemfile.modules` eingetragen ist

### Fehler: "uninitialized constant OpenProject::MsgraphMail"

Das Modul wurde nicht korrekt geladen. Prüfen Sie:

```bash
bundle exec rails runner "puts OpenProject::MsgraphMail.configuration.valid?"
```

## Sicherheitshinweise

- ⚠️ Speichern Sie das Client Secret **niemals** im Code oder in Git
- ⚠️ Verwenden Sie Umgebungsvariablen oder sichere Secrets-Manager
- ⚠️ Rotieren Sie das Client Secret regelmäßig
- ⚠️ Verwenden Sie ein dediziertes Postfach (kein Benutzerpostfach)

## Dateistruktur

```
modules/msgraph_mail/
├── app/
│   ├── controllers/
│   │   └── msgraph_mail/
│   │       └── settings_controller.rb
│   ├── services/
│   │   └── msgraph_mail/
│   │       └── test_connection_service.rb
│   └── views/
│       └── msgraph_mail/
│           └── settings/
│               └── show.html.erb
├── config/
│   ├── locales/
│   │   ├── de.yml
│   │   └── en.yml
│   └── routes.rb
├── lib/
│   └── open_project/
│       └── msgraph_mail/
│           ├── delivery_method.rb
│           ├── engine.rb
│           └── token_manager.rb
├── openproject-msgraph_mail.gemspec
└── README.md
```

## Lizenz

GNU General Public License v3.0

## Autor

Jan Hübener / DATAGROUP SE

## Links

- [Microsoft Graph Mail.Send API Dokumentation](https://learn.microsoft.com/de-de/graph/api/user-sendmail)
- [Azure AD App-Registrierung](https://learn.microsoft.com/de-de/azure/active-directory/develop/quickstart-register-app)
- [OpenProject Dokumentation](https://www.openproject.org/docs/)

---

## Schnellstart

```bash
# 1. Modul installieren
cp -r openproject-msgraph_mail modules/msgraph_mail

# 2. Umgebungsvariablen setzen
export MSGRAPH_TENANT_ID="..."
export MSGRAPH_CLIENT_ID="..."
export MSGRAPH_CLIENT_SECRET="..."
export MSGRAPH_SENDER_EMAIL="noreply@firma.de"

# 3. Bundle & Neustart
bundle install
bundle exec rails server

# 4. Im Browser
# Administration → E-Mails und Benachrichtigungen → MS Graph Mail
# → Verbindung testen → Aktivieren
```
