import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_slidable/flutter_slidable.dart';

void main() async {
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
      debugShowCheckedModeBanner: false,
      title: 'To-Do List App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TodoList(),
      darkTheme: ThemeData.dark(),
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
  @HiveField(3)
  String? tag;

  TodoItem({
    required this.title,
    this.isCompleted = false,
    this.imagePath,
    this.tag,
  });
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
      tag: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, TodoItem obj) {
    writer.write(obj.title);
    writer.write(obj.isCompleted);
    writer.write(obj.imagePath);
    writer.write(obj.tag);
  }
}

class TodoList extends StatefulWidget {
  const TodoList({Key? key}) : super(key: key);

  @override
  _TodoListState createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  late Box<TodoItem> _taskBox;

  bool _showCompletedTasks = false; // Track whether to show completed tasks

  @override
  void initState() {
    super.initState();
    _taskBox = Hive.box<TodoItem>('tasks');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Two tabs: "Tasks" and "Completed"
      child: Scaffold(
        appBar: AppBar(
          title: const Text('To-Do List'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tasks'),
              Tab(text: 'Completed'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTasksListView(), // Display tasks
            _buildCompletedTasksListView(), // Display completed tasks
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final newTask = await showDialog<TodoItem>(
              context: context,
              builder: (context) => TaskDialog(tags: tags),
            );

            if (newTask != null) {
              _taskBox.add(newTask);
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildTasksListView() {
    return ValueListenableBuilder(
      valueListenable: _taskBox.listenable(),
      builder: (context, Box<TodoItem> box, _) {
        final tasks = box.values.where((task) => !task.isCompleted).toList();
        return tasks.isEmpty
            ? Center(child: const Text('No tasks'))
            : ListView.builder(
                itemCount: tasks.length,
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
                              builder: (context) => TaskDialog(
                                initialTask: task,
                                tags: tags,
                              ),
                            );
                            if (updatedTask != null) {
                              setState(() {
                                task.title = updatedTask.title;
                                task.imagePath = updatedTask.imagePath;
                                task.tag = updatedTask.tag;
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
                      trailing: GestureDetector(
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
                        child: Hero(
                          tag: task.imagePath ?? '',
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: task.imagePath != null
                                  ? DecorationImage(
                                      image: FileImage(File(task.imagePath!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      onTap: () async {
                        final updatedTask = await showDialog<TodoItem>(
                          context: context,
                          builder: (context) => TaskDialog(
                            initialTask: task,
                            tags: tags,
                          ),
                        );

                        if (updatedTask != null) {
                          setState(() {
                            task.title = updatedTask.title;
                            task.imagePath = updatedTask.imagePath;
                            task.tag = updatedTask.tag;
                          });
                          task.save();
                        }
                      },
                    ),
                  );
                },
              );
      },
    );
  }

  Widget _buildCompletedTasksListView() {
    return ValueListenableBuilder(
      valueListenable: _taskBox.listenable(),
      builder: (context, Box<TodoItem> box, _) {
        final completedTasks =
            box.values.where((task) => task.isCompleted).toList();
        return completedTasks.isEmpty
            ? Center(child: const Text('No completed tasks'))
            : ListView.builder(
                itemCount: completedTasks.length,
                itemBuilder: (context, index) {
                  final task = completedTasks[index];
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
                              builder: (context) => TaskDialog(
                                initialTask: task,
                                tags: tags,
                              ),
                            );
                            if (updatedTask != null) {
                              setState(() {
                                task.title = updatedTask.title;
                                task.imagePath = updatedTask.imagePath;
                                task.tag = updatedTask.tag;
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
                      trailing: GestureDetector(
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
                        child: Hero(
                          tag: task.imagePath ?? '',
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: task.imagePath != null
                                  ? DecorationImage(
                                      image: FileImage(File(task.imagePath!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      onTap: () async {
                        final updatedTask = await showDialog<TodoItem>(
                          context: context,
                          builder: (context) => TaskDialog(
                            initialTask: task,
                            tags: tags,
                          ),
                        );

                        if (updatedTask != null) {
                          setState(() {
                            task.title = updatedTask.title;
                            task.imagePath = updatedTask.imagePath;
                            task.tag = updatedTask.tag;
                          });
                          task.save();
                        }
                      },
                    ),
                  );
                },
              );
      },
    );
  }
}

class TaskDialog extends StatefulWidget {
  final TodoItem? initialTask;
  final List<String> tags;

  const TaskDialog({Key? key, this.initialTask, required this.tags})
      : super(key: key);

  @override
  _TaskDialogState createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  final TextEditingController _textEditingController = TextEditingController();
  File? _image;
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    if (widget.initialTask != null) {
      _textEditingController.text = widget.initialTask!.title;
      _image = widget.initialTask!.imagePath != null
          ? File(widget.initialTask!.imagePath!)
          : null;
      _selectedTag = widget.initialTask!.tag;
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
      title: Text(widget.initialTask != null ? 'Edit Task' : 'Add Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.blue,
                  width: 2.0,
                ),
                borderRadius: BorderRadius.circular(10.0),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
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
                        child: Row(
                          children: [
                            const Icon(Icons.photo_library),
                            const SizedBox(width: 8),
                            const Text('Gallery'),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _getImageFromCamera,
                        child: Row(
                          children: [
                            const Icon(Icons.camera_alt),
                            const SizedBox(width: 8),
                            const Text('Camera'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_image != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Image.file(_image!, width: 150, height: 150),
                    ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Tag',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedTag,
                    items: widget.tags.map((tag) {
                      return DropdownMenuItem<String>(
                        value: tag,
                        child: Text(tag),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTag = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
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
                  TodoItem(
                    title: taskTitle,
                    imagePath: _image?.path,
                    tag: _selectedTag,
                  ),
                );
              } else {
                final task = TodoItem(
                  title: taskTitle,
                  imagePath: _image?.path,
                  tag: _selectedTag,
                );
                Navigator.pop(context, task);
              }
            }
          },
          child: Text(widget.initialTask != null ? 'Update' : 'Save'),
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

final List<String> tags = ['Personal', 'Business', 'Shopping', 'Work', 'Other'];
