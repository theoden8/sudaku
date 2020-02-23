import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:bit_array/bit_array.dart';


import 'Sudoku.dart';


class NumpadScreenArguments {
  NumpadScreenArguments({this.domain, this.multiselectionMode, this.sd, this.variable});
  BitArray domain;
  int multiselectionMode;
  Sudoku sd;
  int variable = -1;
}

class NumpadScreen extends StatefulWidget {
  static const String routeName = '/numpad_data';

  NumpadScreen();

  State createState() => NumpadScreenState();
}

class NumpadScreenState extends State<NumpadScreen> {
  BitArray multiselection;
  Sudoku sd;
  int variable;
  int multiselectionMode = 0;
  bool reset = true;

  // bool get antiselectionMode => (this.multiselectionMode == 0 && this.variable != -1);

  void _handleOnPress(BuildContext ctx, int val) {
    if(this.multiselectionMode > 0) {
      this.multiselection.invertBit(val);
      // print('multiselection ${multiselection.asIntIterable().toList()}');
      setState((){});
    } else {
      // if(this.antiselectionMode) {
      //   if(!this.multiselection.isEmpty) {
      //     sd.assist.elim.eliminate(this.variable, this.multiselection);
      //   }
      // }
      Navigator.pop(ctx, val);
    }
  }

  // void _handleOnLongPress(BuildContext ctx, int val) {
  //   if(!this.antiselectionMode) {
  //     return;
  //   }
  //   this.multiselection.invertBit(val);
  //   setState(() {});
  // }

  List<Widget> _makeToolbar(BuildContext ctx) {
     var toolbar = List<Widget>();
     if(this.multiselectionMode > 0) {
      toolbar.add(
        IconButton(
          icon: Icon(Icons.save),
          onPressed: (this.multiselection.cardinality != this.multiselectionMode) ? null : () {
            this.reset = true;
            Navigator.pop(ctx, multiselection);
          },
        ),
      );
     }
     return toolbar;
  }

  Widget build(BuildContext ctx) {
    final NumpadScreenArguments args = ModalRoute.of(ctx).settings.arguments;
    final BitArray dom = args.domain;
    this.variable = args.variable;
    this.sd = args.sd;
    final int n = sd.n;
    if(this.reset) {
      if(variable != -1) {
        this.multiselection = dom ^ (dom & sd.assist.getDomain(variable));
      } else {
        this.multiselection = sd.getEmptyDomain();
      }
      this.reset = false;
    }
    this.multiselectionMode = args.multiselectionMode;

    bool isPortrait = MediaQuery.of(ctx).orientation == Orientation.portrait;
    double w = (MediaQuery.of(ctx).size.width - 1.0) / n;
    double h = (MediaQuery.of(ctx).size.height - 1.0) / n;
    double size = (isPortrait ? w : h) - 8.0;
    double sz = size;

    return Scaffold(
      appBar: AppBar(
        title: new Text('Selecting'),
        elevation: 0.0,
        actions: this._makeToolbar(ctx),
      ),
      body: CustomScrollView(
        primary: true,
        slivers: <Widget>[
          SliverGrid.count(
            // crossAxisSpacing: h,
            crossAxisCount: n,
            // mainAxisCount: n,
            children: List<Widget>.generate(n * n, (val) =>
              SizedBox(
                width: sz,
                height: sz,
                child: Container(
                  margin: EdgeInsets.all(sz * 0.1),
                  child: RaisedButton(
                    elevation: this.multiselection[val + 1] ? 0 : 4.0,
                    color: () {
                      if(this.multiselection[val + 1] && this.multiselectionMode > 0) {
                        return Colors.yellow[100];
                      // } else if(this.antiselectionMode && this.multiselection[val + 1]) {
                      //   return Colors.red[100];
                      } else {
                        return Colors.blue[100];
                      }
                    }(),
                    onPressed: (!dom[val + 1] || (
                      this.multiselectionMode > 0
                      && !this.multiselection[val + 1]
                      && this.multiselection.cardinality == this.multiselectionMode))
                    ? null : () {
                      this._handleOnPress(ctx, val + 1);
                    },
                    // onLongPress: (!dom[val + 1] || !this.antiselectionMode)
                    // ? null : () {
                    //   this._handleOnLongPress(ctx, val + 1);
                    // },
                    disabledColor: Colors.grey,
                    padding: EdgeInsets.all(0.0),
                    child: Text(
                      (val + 1).toString(),
                      style: TextStyle(
                        fontSize: sz * 0.4,
                      ),
                    ),
                  ),
                ),
              )
            ).toList(),
          ),
          SliverGrid.count(
            crossAxisCount: 1,
            children: <Widget>[
              Flex(
                direction: Axis.vertical,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      (
                        this.multiselectionMode == 0 ?
                        RaisedButton(
                          padding: EdgeInsets.all(16.0),
                          elevation: 16.0,
                          child: Text('Clear'),
                          onPressed: () {
                            this._handleOnPress(ctx, 0);
                          },
                        )
                        : RaisedButton(
                          padding: EdgeInsets.all(16.0),
                          elevation: 16.0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(Icons.cancel),
                              Text('Cancel'),
                            ],
                          ),
                          onPressed: () {
                            this.reset = true;
                            Navigator.pop(ctx, multiselection);
                          },
                        )
                      ),
                    ],
                  ),
                ]
              ),
            ],
          ),
        ],
      ),
    );
  }
}
