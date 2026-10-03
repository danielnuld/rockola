## ADDED Requirements

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

## MODIFIED Requirements

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
