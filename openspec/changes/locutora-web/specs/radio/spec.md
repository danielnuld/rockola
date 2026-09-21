## ADDED Requirements

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
