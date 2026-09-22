# Rockola

Cliente de musica para Jellyfin en Flutter. iPhone primero, web para iterar la UI.

## Como trabajar aqui

- **Planes en OpenSpec** (`openspec/`): cada fase es un cambio, `/opsx:propose`
  para abrirlo y `/opsx:apply` para implementarlo. El contexto del proyecto vive
  en `openspec/config.yaml`.
- **Ponytail**: lo mas corto que funcione. Antes de escribir, mirar si ya esta en
  el repo, en Flutter o en una dependencia instalada. Atajos deliberados con
  comentario `ponytail:` que diga el techo.
- **CodeGraph** para preguntas estructurales (quien llama a que, que rompe un
  cambio). `.codegraph/` no se versiona.
- **Plano visual**: https://claude.ai/artifact/D14THDp29xLNVPMe49iS4m. Se implementa
  literal de ahi; si algo no funciona en la app real, se cambia el lienzo tambien.

## Comandos

- `flutter run -d web-server --web-port 5000` y abrir `http://localhost:5000` en el
  Chrome de siempre. No `-d chrome`: ese abre un perfil temporal en cada arranque y
  se pierde lo guardado (sesión, servidor del locutor). Jellyfin tiene que tener CORS
  abierto, y el locutor y el servidor de huellas, aceptar el origen
  `http://localhost:5000`.
- `flutter analyze` y `flutter test` antes de cada commit.
- `gh workflow run ios.yml`: IPA sin firmar como artefacto, para Sideloadly.

## Reglas

- Ninguna clave en el repo: la del locutor la pone cada usuario y va al llavero.
- Nada que dependa de CarPlay hasta que haya cuenta de Apple Developer.
- Commits sin atribucion a Claude.
