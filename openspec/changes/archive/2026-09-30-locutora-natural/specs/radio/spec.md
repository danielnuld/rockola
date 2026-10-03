## ADDED Requirements

### Requirement: Ánimo y pausas de la locutora del iPhone
La locutora del iPhone SHALL escribir para ser oída y SHALL elegir un ánimo por entrada
(alegre, emocionada, tranquila o nostálgica) que cambie el ritmo y el tono de la voz,
con una pausa entre frases. El ánimo SHALL no verse en el texto de la pantalla. Sin
ánimo reconocible, SHALL hablar con el ritmo normal.

#### Scenario: Una entrada con ánimo
- **WHEN** el modelo escribe «[emocionada] ¡Aquí viene Reptilia! Súbele.»
- **THEN** la pantalla muestra «¡Aquí viene Reptilia! Súbele.» y la voz va más rápida y más aguda, con una pausa entre las dos frases

#### Scenario: Sin ánimo
- **WHEN** el modelo escribe sin corchetes o con un ánimo que no está en la lista
- **THEN** la entrada se dice entera con el ritmo y el tono normales, sin la etiqueta desconocida

#### Scenario: iOS sin SSML
- **WHEN** el iPhone tiene iOS 15
- **THEN** la entrada se dice como texto plano
