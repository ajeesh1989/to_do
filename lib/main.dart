import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:to_do/box.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TodoItemAdapter());
  await Hive.deleteBoxFromDisk('tasks'); // Delete the 'tasks' box
  await Hive.openBox<TodoItem>('tasks'); // Reopen the 'tasks' box

  // await Hive.openBox<TodoItem>('tasks');
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'To-Do List App',
      theme: ThemeData(
        fontFamily:
            'Poppins', // Replace 'YourFontFamily' with your desired font family
        // Other theme properties can be configured here
      ),
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
          backgroundColor: Colors.grey[300],
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
                style: TextStyle(color: Colors.black),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Reset',
                style: TextStyle(color: Colors.black),
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

  Map<String?, int> countTasksByTag(Box<TodoItem> box) {
    final tagCounts = <String?, int>{};
    for (final task in box.values) {
      final tag = task.tag;
      if (tag != null) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    return tagCounts;
  }

  @override
  Widget build(BuildContext context) {
    // final tagCounts = countTasksByTag(_taskBox);
    // String? _selectedTagError;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
          backgroundColor: Colors.grey[300],
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(125.0),
            child: AppBar(
              elevation: 0,
              backgroundColor: Colors.grey[300],
              title: const Text(
                'To-Do List',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w200,
                    fontSize: 25),
              ),
              bottom: const TabBar(
                indicatorColor: Colors.grey,
                labelStyle: TextStyle(
                  fontSize: 17.0,
                ),
                tabs: [
                  Tab(
                    child: Text(
                      'Tasks',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  Tab(
                    child: Text(
                      'Completed',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                NeuBox(
                  child: PopupMenuButton<String>(
                    color: Colors.grey[300],
                    icon: const Icon(
                      Icons.arrow_drop_down, // Change to your preferred icon
                      color: Colors.black, // Change the color if needed
                    ),
                    onSelected: (tag) {
                      setState(() {
                        _selectedTag = tag;
                      });
                    },
                    itemBuilder: (BuildContext context) {
                      final items = [
                        'All',
                        'Personal',
                        'Home',
                        'Work',
                        'Health',
                        'Finance',
                        'Travel',
                        'Education',
                        'Social',
                        'Grocery',
                        'Projects',
                        'Urgent',
                        'Routine',
                        'Fitness',
                        'Business',
                        'Shopping',
                        'Other'
                      ];

                      // Create a map to count the tags
                      final tagCountMap = <String, int>{};
                      for (final task in _taskBox.values) {
                        final tag = task.tag ??
                            'No Tags'; // Use 'No Tags' for tasks with no tags
                        tagCountMap[tag] = (tagCountMap[tag] ?? 0) + 1;
                      }

                      // Calculate the total count for all tags
                      final totalCount = tagCountMap.values
                          .fold(0, (sum, count) => sum + count);

                      return items
                          .where((tag) =>
                              tag == 'All' ||
                              tagCountMap[tag] != null &&
                                  tagCountMap[tag]! >
                                      0) // Filter tags that are selected or have counts
                          .map<PopupMenuEntry<String>>((String tag) {
                        final count = tag == 'All'
                            ? totalCount
                            : (tagCountMap[tag] ??
                                0); // Display total count for "All" tag
                        return PopupMenuItem<String>(
                          value: tag,
                          child: Text(
                              '$tag (${count.toString()})'), // Display count in brackets
                        );
                      }).toList();
                    },
                  ),
                ),
                NeuBox(
                  child: IconButton(
                    onPressed: () => _showResetConfirmationDialog(context),
                    icon: const Icon(Icons.refresh, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildTasksListView(),
              _buildCompletedTasksListView(),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.transparent,
            elevation: 0,
            onPressed: () async {
              final newTask = await showDialog<TodoItem>(
                context: context,
                builder: (context) => const TaskDialog(
                  tags: [
                    'Personal',
                    'Home',
                    'Health',
                    'Work',
                    'Finance',
                    'Travel',
                    'Education',
                    'Social',
                    'Grocery',
                    'Projects',
                    'Urgent',
                    'Routine',
                    'Fitness',
                    'Business',
                    'Shopping',
                    'Other',
                  ],
                ),
              );

              if (newTask != null) {
                _taskBox.add(newTask);
              }
            },
            child: Transform.scale(
              scale: 1.15, // Adjust the scale factor as needed
              child: const NeuBox(child: Icon(Icons.add, color: Colors.black)),
            ),
          )),
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
            ? const Center(
                child: Text(
                'No tasks here',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ))
            : ListView.separated(
                separatorBuilder: (context, index) {
                  return const Divider(
                    color: Colors.grey,
                  );
                },
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return Slidable(
                    endActionPane: ActionPane(
                      motion: const StretchMotion(),
                      children: [
                        SlidableAction(
                          icon: Icons.edit,
                          backgroundColor: Colors.grey.shade400,
                          onPressed: (context) async {
                            final updatedTask = await showDialog<TodoItem>(
                              context: context,
                              builder: (context) => TaskDialog(
                                initialTask: task,
                                tags: const [
                                  'Personal',
                                  'Home',
                                  'Health',
                                  'Work',
                                  'Finance',
                                  'Travel',
                                  'Education',
                                  'Social',
                                  'Grocery',
                                  'Projects',
                                  'Urgent',
                                  'Routine',
                                  'Fitness',
                                  'Business',
                                  'Shopping',
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
                          backgroundColor: Colors.grey.shade900,
                          onPressed: (context) {
                            showCupertinoDialog(
                              context: context,
                              builder: (context) => CupertinoAlertDialog(
                                title: const Text('Delete Task'),
                                content: const Text(
                                    'Are you sure you want to delete this task?'),
                                actions: [
                                  CupertinoDialogAction(
                                    onPressed: () {
                                      Navigator.of(context)
                                          .pop(); // Close the confirmation dialog
                                    },
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                          color: Colors.grey.shade800),
                                    ),
                                  ),
                                  CupertinoDialogAction(
                                    onPressed: () {
                                      _taskBox.delete(task.key);
                                      Navigator.of(context)
                                          .pop(); // Close the confirmation dialog
                                    },
                                    isDestructiveAction:
                                        true, // Apply a destructive style (usually red text) to this action
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                ],
                              ),
                            );
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
                                fontSize: 14.0, // Adjust the fontSize as needed
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
                        activeColor:
                            Colors.black, // Set the tick color to black
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
                              'Home',
                              'Health',
                              'Work',
                              'Finance',
                              'Travel',
                              'Education',
                              'Social',
                              'Grocery',
                              'Projects',
                              'Urgent',
                              'Routine',
                              'Fitness',
                              'Business',
                              'Shopping',
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
                  );
                });
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
            ? const Center(
                child: Text(
                'No completed tasks',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ))
            : ListView.separated(
                separatorBuilder: (context, index) {
                  return const Divider(
                    color: Colors.grey,
                  );
                },
                itemCount: completedTasks.length,
                itemBuilder: (context, index) {
                  final task = completedTasks[index];
                  return Slidable(
                    endActionPane: ActionPane(
                      motion: const StretchMotion(),
                      children: [
                        SlidableAction(
                          icon: Icons.edit,
                          backgroundColor: Colors.grey.shade400,
                          onPressed: (context) async {
                            final updatedTask = await showDialog<TodoItem>(
                              context: context,
                              builder: (context) => TaskDialog(
                                initialTask: task,
                                tags: const [
                                  'Personal',
                                  'Home',
                                  'Health',
                                  'Work',
                                  'Finance',
                                  'Travel',
                                  'Education',
                                  'Social',
                                  'Grocery',
                                  'Projects',
                                  'Urgent',
                                  'Routine',
                                  'Fitness',
                                  'Business',
                                  'Shopping',
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
                          backgroundColor: Colors.grey.shade900,
                          onPressed: (context) {
                            showCupertinoDialog(
                              context: context,
                              builder: (context) => CupertinoAlertDialog(
                                title: const Text('Delete Task'),
                                content: const Text(
                                    'Are you sure you want to delete this task?'),
                                actions: [
                                  CupertinoDialogAction(
                                    onPressed: () {
                                      Navigator.of(context)
                                          .pop(); // Close the confirmation dialog
                                    },
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                          color: Colors.grey.shade800),
                                    ),
                                  ),
                                  CupertinoDialogAction(
                                    onPressed: () {
                                      _taskBox.delete(task.key);
                                      Navigator.of(context)
                                          .pop(); // Close the confirmation dialog
                                    },
                                    isDestructiveAction:
                                        true, // Apply a destructive style (usually red text) to this action
                                    child: const Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.black),
                                    ),
                                  ),
                                ],
                              ),
                            );
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
                                'Home',
                                'Health',
                                'Work',
                                'Finance',
                                'Travel',
                                'Education',
                                'Social',
                                'Grocery',
                                'Projects',
                                'Urgent',
                                'Routine',
                                'Fitness',
                                'Business',
                                'Shopping',
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
  DateTime? _selectedDateTime;
  final _formKey = GlobalKey<FormState>();
  String? _selectedTagError;

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
      elevation: 50,
      insetPadding: const EdgeInsets.all(8.0),
      contentPadding: const EdgeInsets.all(5), // Set content padding to zero
      backgroundColor: Colors.grey[300],
      title: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          widget.initialTask != null ? 'Edit Task' : 'Add Task',
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.w300, fontSize: 25),
        ),
      ),
      content: SingleChildScrollView(
        // Wrap content with SingleChildScrollView
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        NeuBox(
                          child: TextFormField(
                            controller: _textEditingController,
                            decoration: InputDecoration(
                              errorStyle: const TextStyle(color: Colors.red),
                              errorBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.red)),
                              labelText: 'Task Name',
                              focusedBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              labelStyle: const TextStyle(color: Colors.black),
                            ),
                            style: const TextStyle(color: Colors.black),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Task name cannot be empty';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        NeuBox(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton(
                                onPressed: _getImageFromGallery,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[300],
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.photo_library,
                                        color: Colors.black87),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 5,
                              ),
                              TextButton(
                                onPressed: _getImageFromCamera,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey[300],
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.camera_alt,
                                        color: Colors.black87),
                                  ],
                                ),
                              ),
                              // Close button for the selected photo
                            ],
                          ),
                        ),

                        if (_image != null)
                          NeuBox(
                            child: Column(
                              children: [
                                _image != null
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: () {
                                              showCupertinoDialog(
                                                context: context,
                                                builder: (context) =>
                                                    CupertinoAlertDialog(
                                                  title:
                                                      const Text('Clear Photo'),
                                                  content: const Text(
                                                      'Are you sure you want to clear the selected photo?'),
                                                  actions: [
                                                    CupertinoDialogAction(
                                                      onPressed: () {
                                                        Navigator.of(context)
                                                            .pop(); // Close the confirmation dialog
                                                      },
                                                      child: Text(
                                                        'Cancel',
                                                        style: TextStyle(
                                                            color: Colors
                                                                .grey.shade800),
                                                      ),
                                                    ),
                                                    CupertinoDialogAction(
                                                      onPressed: () {
                                                        setState(() {
                                                          _image =
                                                              null; // Clear the selected photo
                                                        });
                                                        Navigator.of(context)
                                                            .pop(); // Close the confirmation dialog
                                                      },
                                                      isDestructiveAction:
                                                          true, // Apply a destructive style (usually red text) to this action
                                                      child: const Text(
                                                        'Clear',
                                                        style: TextStyle(
                                                            color:
                                                                Colors.black),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: Image.file(_image!,
                                      width: 150, height: 150),
                                ),
                                const SizedBox(
                                  height: 20,
                                ),
                              ],
                            ),
                          )
                        else
                          const SizedBox(height: 20),

                        NeuBox(
                          child: DropdownButtonFormField<String>(
                            borderRadius: BorderRadius.circular(20),
                            dropdownColor: Colors.grey[300],
                            decoration: InputDecoration(
                              errorStyle: const TextStyle(color: Colors.red),
                              errorBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.red),
                              ),
                              labelText: 'Tag',
                              labelStyle: const TextStyle(color: Colors.black),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.grey
                                        .shade300), // Set the border color here
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                    color: Colors.grey
                                        .shade300), // Set the border color here
                              ),
                              errorText:
                                  _selectedTagError, // Display the tag error message
                            ),
                            value: _selectedTag,
                            items: widget.tags.map((tag) {
                              return DropdownMenuItem<String>(
                                value: tag,
                                child: Text(
                                  tag,
                                  style: const TextStyle(color: Colors.black),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedTag = value;
                                _selectedTagError =
                                    null; // Clear any previous tag error
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a tag';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () async {
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
                          child: const NeuBox(
                            child: SizedBox(
                              height: 50,
                              width: 150,
                              child: Center(
                                child: Text(
                                  'Pick Date & Time',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Close button for the selected date & time

                        Column(
                          children: [
                            const SizedBox(
                              height: 5,
                            ),
                            if (_selectedDateTime != null)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'Selected Date & time',
                                      style: TextStyle(
                                          color:
                                              Color.fromARGB(255, 98, 69, 69),
                                          fontSize: 14),
                                    ),
                                  ),
                                  if (_selectedDateTime != null)
                                    IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        showCupertinoDialog(
                                          context: context,
                                          builder: (context) =>
                                              CupertinoAlertDialog(
                                            title:
                                                const Text('Clear Date & Time'),
                                            content: const Text(
                                                'Are you sure you want to clear the selected date & time?'),
                                            actions: [
                                              CupertinoDialogAction(
                                                onPressed: () {
                                                  Navigator.of(context)
                                                      .pop(); // Close the confirmation dialog
                                                },
                                                child: Text(
                                                  'Cancel',
                                                  style: TextStyle(
                                                      color:
                                                          Colors.grey.shade800),
                                                ),
                                              ),
                                              CupertinoDialogAction(
                                                onPressed: () {
                                                  setState(() {
                                                    _selectedDateTime =
                                                        null; // Clear the selected date & time
                                                  });
                                                  Navigator.of(context)
                                                      .pop(); // Close the confirmation dialog
                                                },
                                                isDestructiveAction:
                                                    true, // Apply a destructive style (usually red text) to this action
                                                child: const Text(
                                                  'Clear',
                                                  style: TextStyle(
                                                      color: Colors.black),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    )
                                  else
                                    const SizedBox.shrink(),
                                ],
                              )
                            else
                              const Text(''),
                            const SizedBox(
                              height: 5,
                            ),
                            Text(
                              _selectedDateTime != null
                                  ? DateFormat.yMd()
                                      .add_jm()
                                      .format(_selectedDateTime!)
                                  : '',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 20),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: NeuBox(
                              child: Container(
                                height: 50,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (_formKey.currentState!.validate()) {
                                if (_selectedTag == null) {
                                  setState(() {
                                    _selectedTagError = 'Please select a tag';
                                  });
                                } else {
                                  final newTask = TodoItem(
                                    title: _textEditingController.text,
                                    isCompleted: false,
                                    imagePath: _image?.path,
                                    tag: _selectedTag,
                                    dateTime: _selectedDateTime,
                                  );
                                  Navigator.of(context).pop(newTask);
                                }
                              }
                            },
                            child: NeuBox(
                              child: Container(
                                height: 50,
                                color: Colors.grey[300],
                                child: Center(
                                  child: Text(
                                    widget.initialTask != null
                                        ? 'Update'
                                        : 'Add',
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 30,
                  )
                ],
              ),
            ),
          ),
        ),
      ),
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
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.grey[900],
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
