# 🌐 GDG Event Badges Platform – Core Template

![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Google Cloud Run](https://img.shields.io/badge/Google%20Cloud-4285F4?style=for-the-badge&logo=google-cloud&logoColor=white)
![Firestore](https://img.shields.io/badge/Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2671E5?style=for-the-badge&logo=github-actions&logoColor=white)
![Open Badges](https://img.shields.io/badge/Open%20Badges-000000?style=for-the-badge&logo=openbadges&logoColor=white)

> Plantilla base para crear un sistema completo de **insignias digitales verificables (Open Badges)** para eventos GDG.

Esta plantilla te permite emitir, verificar y mostrar credenciales digitales para tus eventos de comunidad, con un backend en Dart desplegado en **Google Cloud Run** y un frontend estático en **GitHub Pages**.

---

## 📝 Tabla de Contenidos

*   [✨ Características](#-características)
*   [🚀 Cómo Empezar](#-cómo-empezar)
    *   [1. Crear un Repositorio a partir de esta Plantilla](#1-crear-un-repositorio-a-partir-de-esta-plantilla)
    *   [2. Habilitar GitHub Pages](#2-habilitar-github-pages)
    *   [3. Primer Despliegue](#3-primer-despliegue)
    *   [4. Conectar el Frontend con el Backend](#4-conectar-el-frontend-con-el-backend)
*   [☁️ Despliegue Manual del Backend en Cloud Run](#-despliegue-manual-del-backend-en-cloud-run)
*   [🛠️ Uso](#-uso)
    *   [1. Sembrar Datos con `seed.dart`](#1-sembrar-datos-con-seeddart)
        *   [Autenticación para `seed.dart`](#autenticación-para-seeddart)
    *   [2. Reclamar Insignias (Frontend)](#2-reclamar-insignias-frontend)
    *   [3. Desarrollo Local](#3-desarrollo-local)
*   [🤝 Contribuir](#-contribuir)
*   [📄 Licencia](#-licencia)

---

## ✨ Características

*   **🔒 Backend (Dart / Cloud Run):** Gestiona la emisión y verificación de Open Badges, integrándose con Firestore y GitHub Pages.
*   **💻 Frontend (Dart / GitHub Pages):** Interfaz web para que los asistentes reclamen y visualicen sus insignias.
*   **🌍 Estándar Open Badges:** Genera insignias compatibles con la especificación oficial para uso en plataformas de terceros.
*   **⚙️ CI/CD Automatizado:** Flujos de trabajo con **GitHub Actions** para el despliegue del frontend en GitHub Pages.

---

## 🚀 Cómo Empezar

### 1. Crear un Repositorio a partir de esta Plantilla

1.  En GitHub, abre este repositorio.
2.  Haz clic en **“Use this template”**.
3.  Asigna un nombre (por ejemplo, `gdg-alicante/event-badges`) y propietario (tu organización o cuenta personal).

---



### 2. Habilitar GitHub Pages

1.  Ve a **Settings → Pages**.
2.  En “Build and deployment”, selecciona **Deploy from a branch**.
3.  Rama: `gh-pages`, carpeta: `/ (root)`.
4.  Guarda los cambios.

---

### 3. Primer Despliegue

Haz `git push` a la rama `main`.
Esto ejecutará automáticamente:

*   `frontend-deploy.yml` → despliega el frontend a GitHub Pages.

Revisa la pestaña **Actions** para verificar que ambos flujos terminan correctamente.

---

### 4. Conectar el Frontend con el Backend

1.  Cuando el backend se haya desplegado, copia la **Service URL** desde los logs de Actions.
2.  Edita `frontend/web/main.dart`:

    ```dart
    const backendUrl = 'https://tu-servicio-de-cloud-run.run.app';
    ```
3.  Haz `git commit` y `git push` → esto volverá a desplegar el frontend con la URL correcta.

---

## ☁️ Despliegue Manual del Backend en Cloud Run

Puedes desplegar manualmente el backend desde tu entorno local con `gcloud`.

### Ejemplo de comandos reales:

```bash
# 1. Establecer el proyecto activo
gcloud config set project gdg-alicante-472822        

# 2. Construir la imagen Docker y subirla a Container Registry
gcloud builds submit --tag "gcr.io/gdg-alicante-472822/backend:latest" 

# 3. Desplegar el servicio en Cloud Run
gcloud run deploy gdg-event-badges-backend \
   --image "gcr.io/gdg-alicante-472822/backend:latest" \
   --region europe-west8 \
   --allow-unauthenticated \
   --platform managed \
   --set-env-vars GCP_PROJECT_ID=gdg-alicante-472822,GITHUB_REPO_OWNER=gdg-alicante,GITHUB_REPO_NAME=test-badge,GH_PAGES_DEPLOY_TOKEN=github_pat_XXXXXXXXXXXX
```

> ✅ Este comando crea un servicio **Cloud Run público** (sin autenticación) configurado con las variables de entorno necesarias para que el backend se comunique con Firestore y publique certificados en GitHub Pages.

---

## 🛠️ Uso

### 1. Sembrar Datos con `seed.dart`

El script `seed.dart` es una herramienta esencial para inicializar tu plataforma de insignias. Su función principal es **procesar un archivo CSV de asistentes y la información detallada de un evento para crear las definiciones de eventos, asistentes y assets iniciales en Firestore.** Esto prepara la base de datos para la emisión de insignias.

#### Autenticación para `seed.dart`

Si vas a ejecutar el script `seed.dart` localmente, es crucial que tu entorno esté autenticado con Google Cloud. Sigue estos pasos:

1.  Asegúrate de tener el rol `Cloud Datastore User` en tu cuenta de Google Cloud.
2.  Autentícate con la CLI de `gcloud` ejecutando el siguiente comando:

    ```bash
    gcloud auth application-default login
    ```

#### Requisitos

*   [Dart SDK](https://dart.dev/get-dart) instalado.
*   Autenticación local con `gcloud auth application-default login`.

#### Ejemplo real de ejecución:

```bash
GCP_PROJECT_ID="tu-id-de-proyecto" \
GITHUB_REPO_OWNER="tu-organizacion-github" \
GITHUB_REPO_NAME="tu-repositorio-github" \
GH_PAGES_DEPLOY_TOKEN="tu-token-github" \
dart run backend/bin/seed.dart \
  --slug "nombre-unico-del-evento" \
  --name "Nombre del Evento" \
  --description "Descripción detallada del evento y lo que certifica la insignia." \
  --image "URL-de-la-imagen-del-evento" \
  --gdgCommunityLink "URL-del-evento-en-GDG-Community" \
  --issuedOn "AAAA-MM-DDTHH:MM:SSZ" \
  --tags "Tag1, Tag2, Tag3" \
  --narrative "Narrativa de la participación del asistente." \
  --evidence '[{"id": "URL-de-evidencia-1", "narrative": "Descripción de evidencia 1"}, {"id": "URL-de-evidencia-2", "narrative": "Descripción de evidencia 2"}]' \
  --csvPath "/ruta/a/tu/archivo/asistentes.csv"
```

**Parámetros clave:**

*   `--slug`: Identificador único del evento (ej. `devfest-2025`).
*   `--name`: Nombre completo del evento.
*   `--description`: Descripción de la insignia y el evento.
*   `--image`: URL de la imagen de la insignia.
*   `--gdgCommunityLink`: Enlace al evento en GDG Community.
*   `--issuedOn`: Fecha y hora de emisión de la insignia (formato ISO 8601).
*   `--tags`: Etiquetas relevantes para la insignia, separadas por comas.
*   `--narrative`: Texto que describe la participación del asistente.
*   `--evidence`: JSON array de objetos con `id` (URL) y `narrative` para evidencias adicionales.
*   `--csvPath`: **Ruta al archivo CSV que contiene la lista de asistentes.** Cada fila del CSV debe incluir la información necesaria para generar las insignias individuales.

---

### 2. Reclamar Insignias (Frontend)

Los asistentes podrán reclamar sus insignias en:

```
https://<tu-usuario-github>.github.io/<tu-repo>/
```

#### 🔗 Enlace directo a un evento:

```
https://<usuario>.github.io/<repo>/?event=<event_slug>
```

Ejemplo:

```
https://gdg-alicante.github.io/event-badges/?event=devfest-2025
```

---

### 3. Desarrollo Local

#### Requisitos

*   [Dart SDK](https://dart.dev/get-dart) instalado.
*   Backend en Cloud Run (o corriendo localmente).

#### Backend local

```bash
cd backend
dart pub get

export GCP_PROJECT_ID="tu-id"
export GITHUB_REPO_OWNER="tu-org"
export GITHUB_REPO_NAME="tu-repo"
export GH_PAGES_DEPLOY_TOKEN="tu-token"
export PORT="8081"

dart run bin/server.dart
```

#### Frontend local

```bash
cd frontend
dart pub get
dart run build_runner serve
```

Normalmente se sirve en [http://localhost:8080](http://localhost:8080).

---

## 🤝 Contribuir

¡Las contribuciones son bienvenidas!
Por favor, abre un issue o PR con tus mejoras.
(Sigue las convenciones estándar de Dart y GitHub Actions.)

---

## 📄 Licencia

Distribuido bajo la licencia **Apache 2.0** (o la que corresponda a tu GDG).
Consulta el archivo `LICENSE` para más detalles.