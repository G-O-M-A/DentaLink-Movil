# DentaLink

Sistema de gestión para clínicas dentales compuesto por una aplicación móvil para el paciente y un servidor backend centralizado.

## Descripción General
DentaLink es una solución de software orientada al sector odontológico diseñada para optimizar la gestión de expedientes odontológicos, el control de citas y el seguimiento de tratamientos. 

*Nota: Actualmente el proyecto cuenta con el desarrollo base de la aplicación móvil (Flutter) y el servidor backend (Node.js con MySQL), con vistas a integrar los módulos web y servicios adicionales en futuras versiones, servicios como la base de datos en mySQL serán migradas en versiones posteriores.*

---

## Estructura del Proyecto
Proyecto DentaLink/
├── dentalink_app/       # Frontend móvil (Flutter)
└── dentalink_backend/   # Backend / API RESTful (Node.js & MySQL)

---

## Guía de Instalación y Ejecución Local

Siga estos pasos detallados para levantar el entorno de desarrollo de ambos componentes en su computadora.

### Paso 1: Clonar el repositorio
Abra la terminal y clone el repositorio en su máquina local, luego entre a la carpeta principal ejecutando: `git clone [https://github.com/G-O-M-A/DentaLink-Movil.git](https://github.com/G-O-M-A/DentaLink-Movil.git)` y `cd "Proyecto DentaLink"`.

### Paso 2: Configurar y Ejecutar la Base de Datos (MySQL)
1. Asegúrese de tener instalado MySQL y un gestor de su preferencia.
2. Ejecute el siguiente script SQL para crear la base de datos, sus tablas y un usuario de prueba:
`CREATE DATABASE IF NOT EXISTS dentalink_db;`
`USE dentalink_db;`
`CREATE TABLE IF NOT EXISTS users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100) NOT NULL, email VARCHAR(100) UNIQUE NOT NULL, password VARCHAR(255) NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);`
`CREATE TABLE IF NOT EXISTS appointments (id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, patient_name VARCHAR(100) NOT NULL, date VARCHAR(20) NOT NULL, time VARCHAR(20) NOT NULL, reason TEXT NOT NULL, status VARCHAR(50) DEFAULT 'Pendiente', FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);`
`INSERT INTO users (name, email, password) VALUES ('Juan Pérez', 'juan@email.com', '123456');`
`INSERT INTO appointments (user_id, patient_name, date, time, reason, status) VALUES (1, 'Juan Pérez', '25 de Agosto de 2026', '12:00 PM', 'Cambio de modulos', 'Pendiente');`

### Paso 3: Configurar y Ejecutar el Backend
1. Navegue a la carpeta del servidor con `cd dentalink_backend`.
2. Instale las dependencias del proyecto ejecutando `npm install`.
3. Configure sus variables de entorno (cree y configure su archivo `.env` con las credenciales correspondientes para conectar su base de datos **MySQL**).
4. Inicie el servidor de desarrollo ejecutando `npm run dev` (o `node server.js`).

### Paso 4: Configurar y Ejecutar el Frontend (Flutter)
1. Abra una nueva pestaña o ventana en su terminal y entre a la carpeta de la aplicación móvil con `cd dentalink_app`.
2. Instale las dependencias de Flutter ejecutando `flutter pub get`.
3. **Configuración de red:** Abra el archivo de servicios de red en `lib/services/api_services.dart` y modifique la variable `baseUrl` con la dirección IP local de su computadora para permitir que su dispositivo físico o emulador se comunique correctamente con el servidor de Node.js: `static const String baseUrl = 'http://<TU_IP_LOCAL>:3000/api';`.
4. Ejecute la aplicación en su dispositivo o emulador Android ejecutando `flutter run`.

---

## Credenciales de Prueba
Para evaluar el sistema, la autenticación está configurada con un acceso de prueba exclusivo:
* **Correo:** `juan@email.com`
* **Contraseña:** `123456`

---

## Evidencias de Funcionamiento
1. **Autenticación e Inicio de Sesión:** Pantalla principal de acceso al sistema utilizando las credenciales de prueba, bloqueando el acceso a usuarios no autorizados.
2. **Gestión de Citas:** Visualización y control de las citas odontológicas, cambios de módulos y estado de los pacientes.
3. **Recetario y Módulos Clínicos:** Registro estructurado y seguimiento del tratamiento del paciente de forma digital.

---

## Tecnologías y Arquitectura
* **Frontend Móvil:** Flutter (Dart)
* **Backend:** Node.js, Express (API RESTful)
* **Base de Datos:** MySQL
* **Arquitectura:** Cliente-Servidor unificada mediante peticiones HTTP/JSON

---

## Equipo de Desarrollo
* Beltrán Bastida Braulio Santiago
* García García Cesar Eduardo
* Gómez Marván Abraham Raúl
* Ruiz Rincón José Luis

*Asignatura:* Administración y Configuración de Redes WLAN y LAN  
*Profesor:* MBA. Jonathan Zacek Alcázar Jurado