# radio Specification

## Purpose
Rockola FM: cómo se arma la hora, cuándo habla la locutora y qué pasa si no responde.
## Requirements
### Requirement: La hora de radio
Sintonizar SHALL armar una cola de alrededor de una hora (hasta 16 canciones) tomando
por turnos de las mezclas del día, sin repetir canciones. "Cambiar el rumbo" SHALL
armar otra empezando por otra mezcla.

#### Scenario: Sintonizar
- **WHEN** hay seis mezclas y se toca Sintonizar
- **THEN** suena una cola de 16 canciones que alterna mezclas y no repite ninguna

#### Scenario: Cambiar el rumbo
- **WHEN** suena la radio y se toca "Cambiar el rumbo"
- **THEN** empieza otra cola que arranca por otra mezcla

### Requirement: Cuándo habla la locutora
La locutora SHALL hablar al empezar la radio y antes de cada tercera canción; con
"Menos charla", antes de cada sexta y con una sola frase.

#### Scenario: Frecuencia normal
- **WHEN** la radio lleva tres canciones
- **THEN** antes de la cuarta suena una entrada de la locutora

#### Scenario: Menos charla
- **WHEN** "Menos charla" está encendido
- **THEN** entre entradas pasan seis canciones y el servidor recibe `charla: "poca"`

### Requirement: Pedir con tiempo y seguir sin ella
Cada entrada SHALL pedirse al servidor en cuanto empieza la canción anterior a su
turno, y SHALL insertarse en la cola solo si llega antes de que esa canción termine.
Si no llega, falla o no hay servidor configurado, la música SHALL seguir sin entrada.

#### Scenario: Servidor caído
- **WHEN** el servidor del locutor no responde
- **THEN** la radio suena igual, solo música, y la pantalla dice que la locutora no está

#### Scenario: Llega tarde
- **WHEN** la entrada llega cuando ya empezó la canción que debía presentar
- **THEN** se descarta y no interrumpe la música

### Requirement: La pantalla de radio
En la web, la pestaña Radio SHALL mostrar el nombre de la locutora y si está hablando,
el texto de su última entrada, la canción que sigue, "En la rotación" con canciones y
entradas intercaladas, y los botones "Menos charla" y "Cambiar el rumbo".

#### Scenario: Mientras habla
- **WHEN** suena una entrada de la locutora
- **THEN** la pantalla muestra "HABLANDO", su texto, y el mini reproductor dice "<nombre> habla"

### Requirement: Las entradas no cuentan como escuchas
Las entradas de la locutora SHALL no avisarse a Jellyfin ni contarse como saltos.

#### Scenario: Saltar una entrada
- **WHEN** se salta una entrada a los 3 segundos
- **THEN** no se suma ningún salto ni se avisa nada

### Requirement: Datos de vez en cuando
Las entradas entre canciones SHALL pedir un dato al servidor (`dato: true`) una sí y
otra no; la de apertura y todas las de "Menos charla" SHALL ir sin dato. La locutora
del iPhone SHALL no contar datos: el modelo del teléfono los inventaría.

#### Scenario: Una hora normal
- **WHEN** se piden la apertura y tres entradas entre canciones
- **THEN** el servidor recibe `dato` falso, verdadero, falso, verdadero

#### Scenario: Menos charla
- **WHEN** "Menos charla" está encendido
- **THEN** ninguna entrada pide dato

#### Scenario: En el iPhone
- **WHEN** en el iPhone toca una entrada con dato
- **THEN** la locutora habla solo de las canciones, su artista, año y escuchas

### Requirement: La locutora del iPhone
En el iPhone la locutora SHALL generarse en el propio teléfono: el texto con el modelo
de Apple Intelligence y la voz con el sintetizador del sistema, usando la voz en
español de mejor calidad instalada. SHALL llamarse como esa voz y SHALL no llamar
nunca al servidor del locutor.

#### Scenario: Con Apple Intelligence
- **WHEN** en un iPhone 15 Pro con iOS 26 y Apple Intelligence se toca Sintonizar
- **THEN** suena una entrada de apertura hablada, con la voz en español del sistema, y la pantalla muestra su texto y el nombre de la voz

#### Scenario: Sin Apple Intelligence
- **WHEN** el iPhone no tiene Apple Intelligence disponible
- **THEN** la radio suena solo con música y la pantalla dice que la locutora no está

#### Scenario: Nunca el servidor
- **WHEN** hay un servidor del locutor guardado y se sintoniza en el iPhone
- **THEN** no se le hace ninguna petición

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

