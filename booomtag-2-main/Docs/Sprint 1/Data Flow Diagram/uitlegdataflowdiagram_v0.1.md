# Uitleg van het diagram

## Externe entiteit: Booomtag medewerker / Dashboard
- **Rol:** Interne gebruiker die data wil ophalen en bekijken via het dashboard.  
- **Flow:** Stuurt requests via HTTPS met JWT/sessie naar de frontend.  
- **Belangrijk voor STRIDE:** Dit is de actor die mogelijk spoofing of impersonatie kan veroorzaken.

## Frontend (HTML/JS dashboard)
**Functie:**
- Renderen van dashboard UI
- Doorsturen van user input naar backend API  

**Flow:** API calls (JSON) naar backend  

**Security / STRIDE aandacht:**
- **Spoofing:** Frontend moet authenticatie controleren (JWT/session).  
- **Tampering:** Ingevoerde data moet gevalideerd worden om SQL-injection of XSS te voorkomen.

## Backend API (PHP backend)
**Functie:**
- Verwerkt requests van frontend  
- Haalt data op uit RDS via credentials  
- Logt gebeurtenissen naar CloudWatch  
- Tijdens container startup: download app-code van S3  

**Security / STRIDE aandacht:**
- **Repudiation:** Logging naar CloudWatch voorkomt ontkennen van acties  
- **Elevation of Privilege:** Backend moet strikte IAM-rollen gebruiken zodat een gebruiker geen admin kan worden  
- **Tampering:** Code download van S3 moet gecontroleerd worden (hash/signature)  
- **Information Disclosure:** Backend moet gevoelige data niet lekken in responses of logs

## Data stores

| Component | Functie | STRIDE risico’s |
|-----------|--------|----------------|
| S3 Bucket | Bevat applicatiecode die bij startup gedownload wordt | Tampering (gecodeerde upload manipulatie) |
| RDS MySQL | Bewaart alle bedrijfsdata, privé subnet | Information Disclosure (data leaks), DoS (DB overbelasting), Elevation of Privilege (via misconfiguratie) |
| Secrets Manager / Parameter Store | Bevat DB credentials, API keys | Spoofing (ongeautoriseerde toegang), Information Disclosure (credentials uitlekken) |
| CloudWatch Logs | Logging / auditing | Information Disclosure (logs bevatten gevoelige data) |

## Data flows

| Flow | Beschrijving | STRIDE risico’s |
|------|-------------|----------------|
| U → F: HTTPS request + JWT | Medewerker stuurt request | Spoofing (vals account), Tampering (request gemanipuleerd) |
| F → B: API call JSON | Frontend → Backend | Tampering (gemanipuleerde request), Information Disclosure (over TLS, maar controle op logging belangrijk) |
| B → SM: Get Secret Value | Backend haalt DB credentials op | Spoofing (niet geautoriseerde IAM role), Information Disclosure |
| B → RDS: SQL query over TLS | Backend haalt data op | Information Disclosure, DoS (DB overbelasting), Tampering (SQL-injectie) |
| B → CW: Log events | Audit/logging | Information Disclosure (gevoelige info in logs) |
| B → S3: Startup GET object | Container haalt code | Tampering (malware upload), DoS (S3 downtime) |

## Samengevat STRIDE per categorie
- **Spoofing:** U → F, B → SM  
- **Tampering:** F → B, B → S3, B → RDS (SQL-injection risico)  
- **Repudiation:** Backend moet CloudWatch logs gebruiken  
- **Information Disclosure:** B → RDS, B → CW, B → SM  
- **Denial of Service (DoS):** RDS overbelasting, S3 downtime  
- **Elevation of Privilege:** Backend heeft strikte IAM-rollen nodig; geen escalatie via container misconfiguratie
