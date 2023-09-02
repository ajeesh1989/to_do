import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
// ignore: depend_on_referenced_packages
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
  @HiveField(4)
  DateTime? dateTime;

  TodoItem({
    required this.title,
    this.isCompleted = false,
    this.imagePath,
    this.tag,
    this.dateTime,
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
      dateTime: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, TodoItem obj) {
    writer.write(obj.title);
    writer.write(obj.isCompleted);
    writer.write(obj.imagePath);
    writer.write(obj.tag);
    writer.write(obj.dateTime);
  }
}

class TodoList extends StatefulWidget {
  const TodoList({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _TodoListState createState() => _TodoListState();
}

class _TodoListState extends State<TodoList> {
  late Box<TodoItem> _taskBox;
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    _taskBox = Hive.box<TodoItem>('tasks');
  }

  void _resetApp() async {
    await _taskBox.clear();
    setState(() {
      _selectedTag = null;
    });
  }

  Future<void> _showResetConfirmationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset App'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to reset the app?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Reset',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                _resetApp();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.blueGrey.shade900,
        appBar: AppBar(
          title: const Text('To-Do List'),
          bottom: const TabBar(
            labelStyle: TextStyle(
              fontSize: 17.0,
            ), // Adjust the fontSize and fontWeight as needed
            tabs: [
              Tab(
                child: Text(
                  'Tasks',
                ),
              ),
              Tab(
                child: Text(
                  'Completed',
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(
                Icons
                    .arrow_drop_down_circle_outlined, // Change to your preferred icon
                color: Colors.white, // Change the color if needed
              ),
              // child: const Padding(
              //   padding: EdgeInsets.only(top: 20.0),
              //   child: Text('Tags'),
              // ),
              onSelected: (tag) {
                setState(() {
                  _selectedTag = tag;
                });
              },
              itemBuilder: (BuildContext context) {
                final items = [
                  'All',
                  'Personal',
                  'Business',
                  'Shopping',
                  'Work',
                  'Other'
                ];
                return items.map<PopupMenuEntry<String>>((String tag) {
                  return PopupMenuItem<String>(
                    value: tag,
                    child: Text(tag),
                  );
                }).toList();
              },
            ),
            IconButton(
              onPressed: () => _showResetConfirmationDialog(context),
              icon: const Icon(Icons.refresh),
            ),
          ],
          backgroundColor: Colors.grey.shade900,
        ),
        drawer: const Drawer(),
        body: TabBarView(
          children: [
            _buildTasksListView(),
            _buildCompletedTasksListView(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final newTask = await showDialog<TodoItem>(
              context: context,
              builder: (context) => const TaskDialog(
                tags: ['Personal', 'Business', 'Shopping', 'Work', 'Other'],
              ),
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
    _selectedTag ??= 'All';

    return ValueListenableBuilder(
      valueListenable: _taskBox.listenable(),
      builder: (context, Box<TodoItem> box, _) {
        final tasks = _selectedTag == 'All'
            ? box.values.where((task) => !task.isCompleted).toList()
            : box.values
                .where(
                    (task) => !task.isCompleted && (task.tag == _selectedTag))
                .toList();

        return tasks.isEmpty
            ? const Center(child: Text('No tasks'))
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
                                  tags: const [
                                    'Personal',
                                    'Business',
                                    'Shopping',
                                    'Work',
                                    'Other'
                                  ],
                                ),
                              );
                              if (updatedTask != null) {
                                setState(() {
                                  task.title = updatedTask.title;
                                  task.imagePath = updatedTask.imagePath;
                                  task.tag = updatedTask.tag;
                                  task.dateTime = updatedTask.dateTime;
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0), // Adjust padding as needed
                        title: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 17.0, // Adjust the fontSize as needed
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        subtitle: task.dateTime != null
                            ? Text(
                                DateFormat('dd MMMM y, hh:mm a')
                                    .format(task.dateTime!),
                                style: const TextStyle(
                                  fontSize:
                                      14.0, // Adjust the fontSize as needed
                                ),
                              )
                            : null, // Only show subtitle if dateTime is not null
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
                              tags: const [
                                'Personal',
                                'Business',
                                'Shopping',
                                'Work',
                                'Other',
                              ],
                            ),
                          );

                          if (updatedTask != null) {
                            setState(() {
                              task.title = updatedTask.title;
                              task.imagePath = updatedTask.imagePath;
                              task.tag = updatedTask.tag;
                              task.dateTime = updatedTask.dateTime;
                            });
                            task.save();
                          }
                        },
                      ));
                },
              );
      },
    );
  }

  Widget _buildCompletedTasksListView() {
    _selectedTag ??= 'All';

    return ValueListenableBuilder(
      valueListenable: _taskBox.listenable(),
      builder: (context, Box<TodoItem> box, _) {
        final completedTasks = _selectedTag == 'All'
            ? box.values.where((task) => task.isCompleted).toList()
            : box.values
                .where((task) => task.isCompleted && (task.tag == _selectedTag))
                .toList();

        return completedTasks.isEmpty
            ? const Center(child: Text('No completed tasks'))
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
                                  tags: const [
                                    'Personal',
                                    'Business',
                                    'Shopping',
                                    'Work',
                                    'Other'
                                  ],
                                ),
                              );
                              if (updatedTask != null) {
                                setState(() {
                                  task.title = updatedTask.title;
                                  task.imagePath = updatedTask.imagePath;
                                  task.tag = updatedTask.tag;
                                  task.dateTime = updatedTask.dateTime;
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
                      child: Container(
                        alignment:
                            Alignment.centerLeft, // Adjust alignment as needed
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0), // Adjust padding as needed
                          title: Text(
                            task.title,
                            style: TextStyle(
                              decoration: task.isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          subtitle: task.dateTime != null
                              ? Text(
                                  DateFormat.yMd()
                                      .add_jm()
                                      .format(task.dateTime!),
                                )
                              : null, // Only show subtitle if dateTime is not null
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
                                          image:
                                              FileImage(File(task.imagePath!)),
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
                                tags: const [
                                  'Personal',
                                  'Business',
                                  'Shopping',
                                  'Work',
                                  'Other',
                                ],
                              ),
                            );

                            if (updatedTask != null) {
                              setState(() {
                                task.title = updatedTask.title;
                                task.imagePath = updatedTask.imagePath;
                                task.tag = updatedTask.tag;
                                task.dateTime = updatedTask.dateTime;
                              });
                              task.save();
                            }
                          },
                        ),
                      ));
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
  // ignore: library_private_types_in_public_api
  _TaskDialogState createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  final TextEditingController _textEditingController = TextEditingController();
  File? _image;
  String? _selectedTag;
  DateTime? _selectedDateTime;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.initialTask != null) {
      _textEditingController.text = widget.initialTask!.title;
      _image = widget.initialTask!.imagePath != null
          ? File(widget.initialTask!.imagePath!)
          : null;
      _selectedTag = widget.initialTask!.tag;
      _selectedDateTime = widget.initialTask!.dateTime;
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
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialTask != null ? 'Edit Task' : 'Add Task'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.teal,
                    width: 2.0,
                  ),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _textEditingController,
                      decoration: const InputDecoration(
                        errorStyle: TextStyle(color: Colors.yellow),
                        errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.yellow)),
                        labelText: 'Task Name',
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                      style: const TextStyle(color: Colors.white),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Task name cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _getImageFromGallery,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.photo_library),
                            ],
                          ),
                        ),
                        const SizedBox(
                          width: 5,
                        ),
                        ElevatedButton(
                          onPressed: _getImageFromCamera,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.camera_alt),
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
                      decoration: const InputDecoration(
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
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        final selectedDate = await showDatePicker(
                          context: context,
                          initialDate: _selectedDateTime ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );

                        if (selectedDate != null) {
                          // ignore: use_build_context_synchronously
                          final selectedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                              _selectedDateTime ?? DateTime.now(),
                            ),
                          );

                          if (selectedTime != null) {
                            setState(() {
                              _selectedDateTime = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );
                            });
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.teal, // Set the background color to teal
                      ),
                      child: const Text(
                        'Pick Date & Time',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    Text(
                      _selectedDateTime != null
                          ? DateFormat.yMd().add_jm().format(_selectedDateTime!)
                          : '',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white),
          ),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final newTask = TodoItem(
                title: _textEditingController.text,
                isCompleted: false,
                imagePath: _image?.path,
                tag: _selectedTag,
                dateTime: _selectedDateTime, // Assign DateTime
              );
              Navigator.of(context).pop(newTask);
            }
          },
          child: Text(
            widget.initialTask != null ? 'Update' : 'Add',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class DateTimePicker extends StatefulWidget {
  final DateTime? selectedDateTime;
  final ValueChanged<DateTime?> onDateTimeChanged;

  const DateTimePicker({
    Key? key,
    required this.selectedDateTime,
    required this.onDateTimeChanged,
  }) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _DateTimePickerState createState() => _DateTimePickerState();
}

class _DateTimePickerState extends State<DateTimePicker> {
  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);
    final textTheme = themeData.textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          "Select Date and Time",
          style: textTheme.bodySmall,
        ),
        Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: InkWell(
            onTap: () => _selectDate(context),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8),
              child: Text(
                widget.selectedDateTime != null
                    ? DateFormat('dd MMMM y, hh:mm a')
                        .format(widget.selectedDateTime!)
                    : 'Select Date and Time',
                style: widget.selectedDateTime != null
                    ? textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).primaryColor,
                      )
                    : textTheme.titleMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: widget.selectedDateTime ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      // ignore: use_build_context_synchronously
      final pickedTime = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay.fromDateTime(widget.selectedDateTime ?? DateTime.now()),
      );

      if (pickedTime != null) {
        final newDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        widget.onDateTimeChanged(newDateTime);
      }
    }
  }
}

class FullScreenImage extends StatelessWidget {
  final String? imagePath;

  const FullScreenImage({Key? key, this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image'),
      ),
      body: Center(
        child: Hero(
          tag: imagePath ?? '',
          child: Image.file(
            File(imagePath!),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
