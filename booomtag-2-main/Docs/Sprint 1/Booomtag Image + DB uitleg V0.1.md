# Uitleg van de Booomtag Image en Database Architectuur

## Overzicht

De Booomtag-oplossing maakt gebruik van een **multi-container architectuur** die is uitgerold via **AWS ECS Fargate**.  
Binnen deze architectuur draait de **Booomtag webapplicatie** in een **Docker-container** (dus de image), terwijl de **database** wordt gehost in een beheerde **AWS RDS MySQL-instance**.  
Deze opzet zorgt voor **schaalbaarheid, betrouwbaarheid en eenvoud in beheer**, doordat infrastructuurcomponenten geautomatiseerd worden uitgerold via **Terraform**.

## 1. De Booomtag Docker Image (Web Application Container)

De **Booomtag image** vormt de kern van de applicatie.  
Deze image bevat **OctoberCMS**, dat door Booomtag-medewerkers wordt gebruikt om data te beheren, in te zien of aan te passen.

### Belangrijkste eigenschappen

- De webapplicatie is verpakt in een **Docker image**, gebaseerd op `octobercms/october-dev`.
- De container draait binnen **AWS ECS Fargate** — een serverless containeromgeving.
- De container bevat een **webserver (Apache)** en **PHP-runtime** die nodig zijn om OctoberCMS te draaien.
- Via **environment variables** in Terraform wordt de image gekoppeld aan de database:
  - `DB_HOST` → RDS endpoint
  - `DB_DATABASE` → naam van de database
  - `DB_USERNAME` en `DB_PASSWORD` → authenticatiegegevens

### Proces binnen de container

1. De container start op binnen ECS Fargate.  
2. Via de AWS CLI haalt de container automatisch een **ZIP-bestand van OctoberCMS** uit **S3**.  
3. Dit ZIP-bestand wordt uitgepakt in `/var/www/html`.  
4. De webserver start automatisch, waardoor de Booomtag webomgeving bereikbaar is.  
5. Wanneer een medewerker inlogt of data bekijkt, maakt de applicatie een query naar de gekoppelde database.  

### Dependencies

- **AWS ECS** – draait de container.  
- **AWS S3** – slaat de gecomprimeerde applicatiebestanden op.  
- **AWS CloudWatch** – logt de output van de container.  
- **AWS IAM Roles** – regelen de toegangsrechten van de container tot S3 en CloudWatch.  

## 2. De Database (AWS RDS MySQL of container in testomgeving)

De **database** wordt gescheiden gehouden van de webapplicatie en draait in een eigen omgeving voor veiligheid en stabiliteit.

### Twee mogelijke implementaties

1. **MySQL-container** binnen ECS (zoals gedefinieerd in `aws_ecs_task_definition.database`).  
2. **AWS RDS MySQL-instance** — de voorkeur in productie.  

### Kenmerken van de database-opzet

- De database draait in een **private subnet** binnen de VPC, zodat deze niet publiek toegankelijk is.  
- De database bevat alle Booomtag-gegevens, zoals:  
  - geregistreerde producten  
  - gebruikersinformatie  
  - loggegevens  
  - instellingen/configuraties  
- Terraform gebruikt variabelen zoals:  
  - `mysql_database`  
  - `mysql_user`  
  - `mysql_password`  
- Bij het uitrollen wordt automatisch een SQL-bestand (`sql_fate_data.sql`) uitgevoerd om testdata te vullen.  

### Communicatie met de webcontainer

- De webapplicatie (in ECS) gebruikt de **RDS endpoint** als hostadres (`DB_HOST`).  
- Beveiliging gebeurt via **security groups**, die verkeer op poort **3306 (MySQL)** toelaten tussen webapp en database.  
- Inkomend verkeer van buitenaf wordt **niet toegestaan** naar de database.  

## 3. Samenwerking binnen AWS ECS Fargate

De hele infrastructuur draait binnen **Amazon Web Services**, opgebouwd via **Terraform**.  

### Belangrijkste componenten

| Component | Functie | Type |
|------------|----------|------|
| **ECS Cluster** | Beheert containers | AWS ECS |
| **Web App Service** | Draait Booomtag webapp | Fargate |
| **Database Service** | Draait MySQL of RDS | Fargate / RDS |
| **S3 Bucket** | Slaat CMS-bestanden op | AWS S3 |
| **VPC + Subnets** | Netwerkisolatie | AWS Networking |
| **IAM Roles** | Rechtenbeheer | AWS IAM |
| **CloudWatch** | Logging & monitoring | AWS CloudWatch |

### Terraform zorgt voor

- Een **VPC** met aparte subnetten (publiek voor de webapp, privé voor de database).  
- Een **Application Load Balancer (ALB)** die inkomend verkeer verdeelt over meerdere **Fargate-tasks via target groups**, waardoor schaalbaarheid en hoge beschikbaarheid worden gegarandeerd.  
- **Security Groups** die alleen noodzakelijk verkeer toestaan (HTTP en MySQL).  
- Automatische deployment van zowel web- als databaseservice.  

## 4. Hoe de Database in de Image past

De **Booomtag image** zelf bevat **geen lokale database**.  
In plaats daarvan **verbindt de webapp** binnen de container zich via de environment variables met de **externe database (RDS of MySQL-container)**.  

### Voorbeeld: dataverkeer via het dashboard

1. De gebruiker opent het dashboard in de browser.  
2. De request komt binnen op de **Application Load Balancer**, die het verkeer verdeelt naar een beschikbare webcontainer (ECS Fargate).  
3. De webcontainer voert een SQL-query uit naar de MySQL-database.  
4. De database stuurt de resultaten terug (zoals productinformatie of gebruikersdata).  
5. De applicatie rendert de resultaten in HTML en toont deze aan de medewerker.  

## 5. Dependencies & Beveiliging

### Software dependencies

- **OctoberCMS** voor de weblaag  
- **PHP PDO** voor databaseverbinding  
- **AWS CLI** binnen de container om S3-bestanden op te halen  

### Cloud dependencies

- **ECS Task Execution Role** met toegang tot S3 en CloudWatch  
- **RDS Security Group** met poort 3306 open voor ECS-tasks  
- **Terraform** voor infrastructuurbeheer  

### Beveiliging

- Database draait in een **private subnet** → niet publiek bereikbaar.  
- Alleen ECS containers met juiste **IAM-role** kunnen verbinding maken.  
- **Inkomend verkeer naar de webapplicatie loopt via de Application Load Balancer (ALB)** en niet rechtstreeks naar de containers, wat de veiligheid verhoogt.  
- In productie: wachtwoorden moeten via **AWS Secrets Manager** worden beheerd (momenteel hardcoded in testfase).  

## 6. Conclusie

De **Booomtag-image** is ontworpen als een **schaalbare, containergebaseerde webapplicatie** binnen AWS.  
De databasecomponent is losgekoppeld om **betere beveiliging, prestaties en onderhoudbaarheid** te garanderen.  
Door gebruik van **Terraform**, **ECS Fargate**, **RDS** en een **Application Load Balancer met target groups**, is de hele infrastructuur **geautomatiseerd, schaalbaar en geschikt voor groei**.
