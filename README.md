# treproject

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## Exportação de códigos e fotos

- Ao tocar no botão de compartilhar na tela de lista, o app gera uma pasta temporária contendo:
	- Um arquivo `codigos_barras.txt` com a listagem dos códigos e status.
	- Todas as fotos anexadas, com o nome do arquivo sendo o próprio código (extensão preservada quando possível).
- Por limitações de compartilhamento no Android/iOS, essa pasta é compactada automaticamente em um arquivo `.zip` e então compartilhada.
- O nome do arquivo gerado segue o formato `exportacao_<timestamp>.zip`.