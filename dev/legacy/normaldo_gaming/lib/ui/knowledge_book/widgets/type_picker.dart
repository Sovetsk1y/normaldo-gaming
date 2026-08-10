import 'package:flutter/material.dart';
import 'package:normaldo_gaming/core/theme.dart';

enum Types { good, bad }

class TypePicker extends StatefulWidget {
  const TypePicker({super.key, required this.onChanged});

  final ValueChanged<Types> onChanged;

  @override
  State<TypePicker> createState() => _TypePickerState();
}

class _TypePickerState extends State<TypePicker> {
  Types _type = Types.good;

  @override
  Widget build(BuildContext context) {
    const containerWidth = 80.0;
    const containerHeight = 40.0;
    const pizzaDimension = 30.0;
    const cocktailDimension = 27.0;
    return Stack(
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _type = Types.good;
                });
                widget.onChanged(Types.good);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: containerHeight,
                width: containerWidth,
                decoration: BoxDecoration(
                    color:
                        _type == Types.good ? NGTheme.green1 : NGTheme.purple2,
                    border: Border.all(
                      color: _type == Types.good
                          ? NGTheme.green1
                          : NGTheme.auraRed,
                      width: 2,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(100),
                      bottomLeft: Radius.circular(100),
                    )),
                child: Center(
                  child: Image.asset(
                    'assets/images/pizza.png',
                    width: pizzaDimension,
                    height: pizzaDimension,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _type = Types.bad;
                });
                widget.onChanged(Types.bad);
              },
              child: Container(
                height: containerHeight,
                width: containerWidth,
                decoration: BoxDecoration(
                    color:
                        _type == Types.bad ? NGTheme.auraRed : NGTheme.purple2,
                    border: Border.all(
                      color:
                          _type == Types.bad ? NGTheme.auraRed : NGTheme.green1,
                      width: 2,
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(100),
                      bottomRight: Radius.circular(100),
                    )),
                child: Center(
                  child: Image.asset(
                    'assets/images/cocktail.png',
                    width: cocktailDimension,
                    height: cocktailDimension,
                  ),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
}
