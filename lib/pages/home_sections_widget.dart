import 'package:flutter/material.dart';

class HomeSection {
  final String title;
  final String description;
  final IconData icon;

  HomeSection({
    required this.title,
    required this.description,
    required this.icon,
  });
}

List<HomeSection> getHomeSections() {
  return [
    HomeSection(
      title: 'Contador',
      description: 'Botón que incrementa el contador y reproduce la canción seleccionada.',
      icon: Icons.add,
    ),
    HomeSection(
      title: 'Búsqueda',
      description: 'Campo y botón para buscar canciones con getHomeSections().',
      icon: Icons.search,
    ),
    HomeSection(
      title: 'Progreso de reproducción',
      description: 'Barra de progreso y buffer para la canción actual.',
      icon: Icons.music_note,
    ),
    HomeSection(
      title: 'Reproductor',
      description: 'Botón de play/pausa y control de posición de audio.',
      icon: Icons.play_arrow,
    ),
  ];
}

class HomeSectionsPage extends StatelessWidget {
  const HomeSectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = getHomeSections();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secciones de la página principal'),
      ),
      body: ListView.separated(
        itemCount: sections.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final section = sections[index];
          return ListTile(
            leading: Icon(section.icon),
            title: Text(section.title),
            subtitle: Text(section.description),
          );
        },
      ),
    );
  }
}
