import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_slidable/flutter_slidable.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TodoItemAdapter());
  await Hive.openBox<TodoItem>('tasks');
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do List App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TodoList(),
    );
  }
}

@HiveType(typeId: 0)
class TodoItem extends HiveObject {
  @HiveField(0)
  String title;
  @HiveField(1)
  bool isCompleted;
  @HiveField(2)
  String? imagePath;

  TodoItem({required this.title, this.isCompleted = false, this.imagePath});
}

class TodoItemAdapter extends TypeAdapter<TodoItem> {
  @override
  final int typeId = 0;

  @override
  TodoItem read(BinaryReader reader) {
    return TodoItem(
      title: reader.read(),
      isCompleted: reader.read(),
      imagePath: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, TodoItem obj) {
    writer.write(obj.title);
    writer.write(obj.isCompleted);
    writer.write(obj.imagePath);
  }
}

class TodoList extends StatefulWidget {
  const TodoList({Key? key}) : super(key: key);

  @override
  _TodoListState createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  late Box<TodoItem> _taskBox;

  @override
  void initState() {
    super.initState();
    _taskBox = Hive.box<TodoItem>('tasks');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('To-Do List')),
      // Inside TodoList widget's build method
      body: ValueListenableBuilder(
        valueListenable: _taskBox.listenable(),
        builder: (context, Box<TodoItem> box, _) {
          final tasks = box.values.toList();
          return Center(
            child: tasks.isEmpty
                ? const Text('No tasks')
                : ListView.separated(
                    itemCount: tasks.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return Slidable(
                        endActionPane: ActionPane(
                          motion: const StretchMotion(),
                          children: [
                            SlidableAction(
                              icon: Icons.edit,
                              backgroundColor: Colors.green.shade200,
                              onPressed: (context) async {
                                final updatedTask = await showDialog<TodoItem>(
                                  context: context,
                                  builder: (context) =>
                                      TaskDialog(initialTask: task),
                                );
                                if (updatedTask != null) {
                                  setState(() {
                                    task.title = updatedTask.title;
                                    task.imagePath = updatedTask.imagePath;
                                  });
                                  task.save();
                                }
                              },
                            ),
                            SlidableAction(
                              icon: Icons.delete,
                              backgroundColor: Colors.red.shade200,
                              onPressed: (context) {
                                _taskBox.delete(task.key);
                              },
                            ),
                          ],
                        ),
                        child: ListTile(
                          title: Text(
                            task.title,
                            style: TextStyle(
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          leading: Checkbox(
                            value: task.isCompleted,
                            onChanged: (value) {
                              setState(() {
                                task.isCompleted = value!;
                              });
                              task.save();
                            },
                          ),
                          trailing: Hero(
                            tag: task.imagePath ?? '',
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      return FullScreenImage(
                                        imagePath: task.imagePath,
                                      );
                                    },
                                  ),
                                );
                              },
                              child: task.imagePath != null
                                  ? Image.file(
                                      File(task.imagePath!),
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                          ),
                          onTap: () async {
                            final updatedTask = await showDialog<TodoItem>(
                              context: context,
                              builder: (context) =>
                                  TaskDialog(initialTask: task),
                            );

                            if (updatedTask != null) {
                              setState(() {
                                task.title = updatedTask.title;
                                task.imagePath = updatedTask.imagePath;
                              });
                              task.save();
                            }
                          },
                        ),
                      );
                    },
                  ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newTask = await showDialog<TodoItem>(
            context: context,
            builder: (context) => const TaskDialog(),
          );

          if (newTask != null) {
            _taskBox.add(newTask);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class TaskDialog extends StatefulWidget {
  final TodoItem? initialTask;

  const TaskDialog({Key? key, this.initialTask}) : super(key: key);

  @override
  _TaskDialogState createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  final TextEditingController _textEditingController = TextEditingController();
  File? _image;

  late Box<TodoItem> _taskBox;

  @override
  void initState() {
    super.initState();
    _taskBox = Hive.box<TodoItem>('tasks');
    if (widget.initialTask != null) {
      _textEditingController.text = widget.initialTask!.title;
      _image = widget.initialTask!.imagePath != null
          ? File(widget.initialTask!.imagePath!)
          : null;
    }
  }

  Future<void> _getImageFromGallery() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = basename(pickedImage.path);
      final savedImage = File('${appDir.path}/$fileName');

      final pickedImageBytes = await pickedImage.readAsBytes();
      await savedImage.writeAsBytes(pickedImageBytes);

      setState(() {
        _image = savedImage;
      });
    }
  }

  Future<void> _getImageFromCamera() async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: ImageSource.camera);

    if (pickedImage != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = basename(pickedImage.path);
      final savedImage = File('${appDir.path}/$fileName');

      final pickedImageBytes = await pickedImage.readAsBytes();
      await savedImage.writeAsBytes(pickedImageBytes);

      setState(() {
        _image = savedImage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _textEditingController,
            decoration: const InputDecoration(labelText: 'Task Name'),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _getImageFromGallery,
                child: const Icon(Icons.photo_library),
              ),
              ElevatedButton(
                onPressed: _getImageFromCamera,
                child: const Icon(Icons.camera_alt),
              ),
            ],
          ),
          if (_image != null) Image.file(_image!, width: 150, height: 200),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final taskTitle = _textEditingController.text;
            if (taskTitle.isNotEmpty) {
              if (widget.initialTask != null) {
                Navigator.pop(
                  context,
                  TodoItem(title: taskTitle, imagePath: _image?.path),
                );
              } else {
                final task =
                    TodoItem(title: taskTitle, imagePath: _image?.path);
                Navigator.pop(context, task);
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String? imagePath;

  const FullScreenImage({Key? key, this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Hero(
          tag: imagePath ?? '',
          child: imagePath != null
              ? Image.file(File(imagePath!))
              : const Text('No image'),
        ),
      ),
    );
  }
}
