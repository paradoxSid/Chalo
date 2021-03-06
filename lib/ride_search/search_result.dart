import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_transport/config/keys.dart';
import 'package:shared_transport/login/login_page.dart';
import 'package:shared_transport/ride_search/drive_card.dart';
import 'package:shared_transport/utils/localizations.dart';
import 'package:shared_transport/widgets/custom_dialog.dart';
import 'package:shared_transport/models/models.dart';
import 'package:shared_transport/widgets/empty_state.dart';
import 'dart:math' as math;

/// Converter screen where users can input amounts to convert.
///
/// Currently, it just displays a list of mock units.
///
/// While it is named ConverterRoute, a more apt name would be ConverterScreen,
/// because it is responsible for the UI at the route's destination.
///
class SearchResultPage extends StatefulWidget {
  final search;

  SearchResultPage({@required this.search});

  @override
  _SearchResultPageState createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  ScrollController _hideButtonController;
  var _isVisible = true;
  var _searchHeight = 0.0;
  var _isShowing = false;
  var _refreshRequired = true;
  var _isLoading = true;
  // Sort Options
  List<String> _allSortOptions = [
    'Rating',
    'Seats Available: more to less',
    'Seats Available: less to more',
    'Time: Early to Late',
    'Time: Late to Early'
  ];
  var _sortOptionSelected = 'Rating';
  // Filter Options
  var _filterSeatsSelected;
  var _filterMinRating = 0;
  // car filter
  List<String> _allCarTypes = ['Hatchback', 'SUV', 'Sedan', 'Motorbike'];
  List<String> _filterCarTypes = [];
  // Result ListView
  List<RideModel> rides = [];
  ListView resultListView;

  @override
  void initState() {
    super.initState();
    _filterCarTypes = List.from(_allCarTypes);
    _hideButtonController = new ScrollController();
    _hideButtonController.addListener(() {
      setState(() {
        if (_hideButtonController.offset < 0 &&
            _hideButtonController.offset >= -85 &&
            !_isShowing) {
          _searchHeight = -_hideButtonController.offset;
          if (_searchHeight > 80) {
            _isShowing = true;
            _searchHeight = 85;
          }
        }
        if (_hideButtonController.offset > 0 && _isShowing) {
          _searchHeight = 85 - _hideButtonController.offset * 4;
          if (_searchHeight < 5) {
            _isShowing = false;
            _searchHeight = 0;
          }
        }
        _isVisible = (_hideButtonController.position.userScrollDirection ==
                    ScrollDirection.reverse &&
                _isVisible == true)
            ? false
            : (_hideButtonController.position.userScrollDirection ==
                        ScrollDirection.forward &&
                    _isVisible == false)
                ? true
                : _isVisible;
      });
    });
    _makeGetRequest();
  }

  _makeGetRequest() async {
    WidgetsFlutterBinding.ensureInitialized();
    var _prefs = SharedPreferences.getInstance();
    final SharedPreferences prefs = await _prefs;

    final response = await get(Keys.serverURL + 'ride/search', headers: {
      'token': prefs.getString('token'),
      'email': prefs.getString('email'),
      'data': jsonEncode(widget.search),
    });
    if (response.statusCode == 200) {
      List jsonRides = json.decode(response.body)['rides'];

      setState(() {
        rides = jsonRides.map((ride) {
          return RideModel(
            type: ride['type'],
            from: LocationLatLng(
                ride['from']['name'], ride['from']['lat'], ride['from']['lon']),
            to: LocationLatLng(
                ride['to']['name'], ride['to']['lat'], ride['to']['lon']),
            driveDate: ride['driveDate'],
            fromTime: ride['fromTime'],
            toTime: ride['toTime'],
            vehicle: widget.search['type'] == "ride"
                ? Vehicle(
                    name: ride['vehicle']['name'],
                    modelName: ride['vehicle']['modelName'],
                    seats: ride['vehicle']['seats'],
                    number: ride['vehicle']['number'],
                    pic: ride['vehicle']['pic'],
                    type: ride['vehicle']['type'],
                    index: ride['vehicle']['index'])
                : Vehicle(
                    name: null,
                    modelName: null,
                    seats: null,
                    number: null,
                    pic: null,
                    type: null,
                    index: null,
                  ),
            slots: ride['slots'],
            dId: ride['dId'],
            driver: User(
                name: ride['driver']['name'],
                email: ride['driver']['email'],
                rating: ride['driver']['rating'] * 1.0,
                pic: ride['driver']['pic'],
                nod: ride['driver']['nod']),
          );
        }).toList();
        _isLoading = false;
        _refreshRequired = true;
      });
    } else {
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) => CustomDialog(
          icon: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Icon(
              Icons.error_outline,
              size: 40,
              color: Theme.of(context).accentColor,
            ),
          ),
          title: 'Error',
          description: 'Something went wrong\nPlease try again',
          buttons: FlatButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (BuildContext context) => LoginPage()),
                ModalRoute.withName(''),
              );
            },
            child: Text(
              'OK',
              style:
                  TextStyle(color: Theme.of(context).accentColor, fontSize: 20),
            ),
          ),
        ),
      );
    }
  }

  String getDayOfWeek(date) {
    int dNum = DateTime.utc(
      int.parse(date.split('/')[2]),
      int.parse(date.split('/')[1]),
      int.parse(date.split('/')[0]),
    ).weekday;
    var days = [
      'Monday',
      'Tuesday',
      'Wednusday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[dNum - 1];
  }

  String getMonthOfYear(date) {
    int mNum = DateTime.utc(
      int.parse(date.split('/')[2]),
      int.parse(date.split('/')[1]),
      int.parse(date.split('/')[0]),
    ).month;
    var months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[mNum - 1];
  }

  Widget sortOption(String option, StateSetter state) {
    return Container(
      child: ListTile(
        onTap: () {
          state(() {
            _sortOptionSelected = option;
            Navigator.pop(context);
          });
        },
        trailing: option == _sortOptionSelected
            ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.done,
                  color: Theme.of(context).accentColor,
                ),
              )
            : null,
        title: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            AppLocalizations.of(context).localisedText[option.toLowerCase()],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: option == _sortOptionSelected
                  ? Theme.of(context).accentColor
                  : Theme.of(context).primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> carType() {
    List<Widget> carTypes = _allCarTypes.map((String val) {
      var _isSelected = _filterCarTypes.contains(val);
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter sheetState) {
          return Padding(
            padding: const EdgeInsets.all(2),
            child: InkWell(
              onTap: () {
                sheetState(() {
                  if (_isSelected) {
                    _isSelected = false;
                    _filterCarTypes.remove(val);
                  } else {
                    _isSelected = true;
                    _filterCarTypes.add(val);
                  }
                });
              },
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(3),
                shadowColor:
                    _isSelected ? Theme.of(context).accentColor : Colors.white,
                color:
                    _isSelected ? Theme.of(context).accentColor : Colors.white,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Text(
                    val,
                    style: TextStyle(
                        color: _isSelected
                            ? Colors.white
                            : Theme.of(context).accentColor),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }).toList();
    return carTypes;
  }

  _showSortOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Color(0xFF737373),
      builder: (builder) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter sheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20.0),
                  topRight: const Radius.circular(20.0),
                ),
              ),
              child: Column(
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    height: 50,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(width: 1, color: Colors.black12),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(left: 12.0),
                          child: Text(
                            AppLocalizations.of(context)
                                .localisedText['sort_by'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: _allSortOptions.map((option) {
                      return sortOption(option, sheetState);
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((onValue) {
      setState(() {
        _refreshRequired = true;
      });
    });
  }

  _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Color(0xFF737373),
      builder: (builder) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter sheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20.0),
                  topRight: const Radius.circular(20.0),
                ),
              ),
              child: Column(
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    height: 50,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(width: 1, color: Colors.black12),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(left: 12.0),
                          child: Text(
                            AppLocalizations.of(context)
                                .localisedText['filter_by'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    title: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        widget.search.runtimeType == "ride"
                            ? AppLocalizations.of(context)
                                .localisedText['seats_available']
                            : AppLocalizations.of(context)
                                .localisedText['slots_available'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    trailing: SizedBox(
                      width: 130,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          widget.search['type'] == "ride"
                              ? Expanded(
                                  child: DropdownButton<int>(
                                    hint: Text(
                                      AppLocalizations.of(context)
                                          .localisedText['select'],
                                      style: TextStyle(
                                        color: Theme.of(context).accentColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    underline: Container(),
                                    iconEnabledColor:
                                        Theme.of(context).accentColor,
                                    items: [1, 2, 3, 4, 5].map((int val) {
                                      return DropdownMenuItem<int>(
                                        value: val,
                                        child: Text(
                                          '${val.toString()} ${AppLocalizations.of(context).localisedText['seats']}',
                                          style: TextStyle(
                                              color:
                                                  Theme.of(context).accentColor,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      );
                                    }).toList(),
                                    isExpanded: true,
                                    value: _filterSeatsSelected,
                                    onChanged: (val) {
                                      sheetState(() {
                                        _filterSeatsSelected = val;
                                      });
                                    },
                                  ),
                                )
                              : Container(
//                            color: Colors.amber,
                                  width: 80,
                                  height: 30,
                                  child: TextField(
                                    decoration: InputDecoration(
//                                suffixText: "x 100 Kg",
                                      enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide.none),
                                      focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide.none),
                                      hintText: 'Slots ?',
                                    ),
                                    keyboardType: TextInputType.text,
                                    onSubmitted: (val) {
                                      setState(() {
                                        _filterSeatsSelected = val;
//                            _goodsSlotsAvailable = int.parse(val);
//                                print((_goodsSlotsAvailable));
                                      });
                                    },
//                              submitOnSuggestionTap: true,
//                              clearOnSubmit: false,
                                  ),
                                ),
                          IconButton(
                            icon: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.rotationY(math.pi),
                              child: Icon(Icons.refresh),
                            ),
                            onPressed: () {
                              sheetState(() {
                                _filterSeatsSelected = null;
                              });
                            },
                          )
                        ],
                      ),
                    ),
                  ),
                  ListTile(
                    title: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        AppLocalizations.of(context)
                            .localisedText['min_rating'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    trailing: SizedBox(
                      width: 170,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          GestureDetector(
                            child: Icon(
                              Icons.star,
                              color: _filterMinRating >= 1
                                  ? Theme.of(context).accentColor
                                  : Colors.grey,
                            ),
                            onTap: () {
                              sheetState(() {
                                _filterMinRating = 1;
                              });
                            },
                          ),
                          GestureDetector(
                            child: Icon(
                              Icons.star,
                              color: _filterMinRating >= 2
                                  ? Theme.of(context).accentColor
                                  : Colors.grey,
                            ),
                            onTap: () {
                              sheetState(() {
                                _filterMinRating = 2;
                              });
                            },
                          ),
                          GestureDetector(
                            child: Icon(
                              Icons.star,
                              color: _filterMinRating >= 3
                                  ? Theme.of(context).accentColor
                                  : Colors.grey,
                            ),
                            onTap: () {
                              sheetState(() {
                                _filterMinRating = 3;
                              });
                            },
                          ),
                          GestureDetector(
                            child: Icon(
                              Icons.star,
                              color: _filterMinRating >= 4
                                  ? Theme.of(context).accentColor
                                  : Colors.grey,
                            ),
                            onTap: () {
                              sheetState(() {
                                _filterMinRating = 4;
                              });
                            },
                          ),
                          GestureDetector(
                            child: Icon(
                              Icons.star,
                              color: _filterMinRating >= 5
                                  ? Theme.of(context).accentColor
                                  : Colors.grey,
                            ),
                            onTap: () {
                              sheetState(() {
                                _filterMinRating = 5;
                              });
                            },
                          ),
                          IconButton(
                            icon: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.rotationY(math.pi),
                              child: Icon(Icons.refresh),
                            ),
                            onPressed: () {
                              sheetState(() {
                                _filterMinRating = 0;
                              });
                            },
                          )
                        ],
                      ),
                    ),
                  ),
                  ListTile(
                    title: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        AppLocalizations.of(context)
                            .localisedText['vehicle_type'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    trailing: IconButton(
                      icon: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(math.pi),
                        child: Icon(Icons.refresh),
                      ),
                      onPressed: () {
                        sheetState(() {
                          _filterCarTypes = List.from(_allCarTypes);
                        });
                      },
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    child: Wrap(
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.start,
                      children: carType(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((onValue) {
      setState(() {
        _refreshRequired = true;
      });
    });
  }

  int _resultSorter(RideModel a, RideModel b) {
    int index = _allSortOptions.indexOf(_sortOptionSelected);

    if (index == 0)
      return b.driver.rating.compareTo(a.driver.rating);
    else if (index == 1)
      return b.slots.compareTo(a.slots);
    else if (index == 2)
      return a.slots.compareTo(b.slots);
    else if (index == 3)
      return a.fromTime.compareTo(b.fromTime);
    else if (index == 4)
      return b.fromTime.compareTo(a.fromTime);
    else
      return a.driver.rating.compareTo(b.driver.rating);
  }

  @override
  Widget build(BuildContext context) {
    Widget appBar = AppBar(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      elevation: 2,
      titleSpacing: 0,
      title: Text(AppLocalizations.of(context).localisedText['search_result']),
    );

    Widget floatingButton = _isVisible
        ? Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              color: Theme.of(context).accentColor.withOpacity(.9),
            ),
            height: 50,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                InkWell(
                  onTap: () {
                    _showSortOptions();
                  },
                  child: Container(
                    width: 100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Spacer(),
                        Icon(
                          Icons.sort,
                          color: Colors.white,
                        ),
                        Spacer(),
                        Text(
                          AppLocalizations.of(context).localisedText['sort_by'],
                          style: TextStyle(color: Colors.white),
                        ),
                        Spacer(),
                      ],
                    ),
                  ),
                ),
                VerticalDivider(color: Colors.white),
                InkWell(
                  onTap: () {
                    _showFilterOptions();
                  },
                  child: Container(
                    width: 100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Spacer(),
                        Icon(
                          Icons.filter_list,
                          color: Colors.white,
                        ),
                        Spacer(),
                        Text(
                          AppLocalizations.of(context)
                              .localisedText['filter_by'],
                          style: TextStyle(color: Colors.white),
                        ),
                        Spacer(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        : null;

    Widget searchResults() {
      if (_refreshRequired) {
        rides.sort(_resultSorter);
        List<Widget> results = rides.map((ride) {
          var data = {
            'ride': ride,
            'rider': widget.search,
          };
          Widget drive = DriveCard(ride: data);

          drive = (_filterSeatsSelected != null &&
                  ride.slots != _filterSeatsSelected)
              ? Container()
              : drive;

          drive = ride.driver.rating >= _filterMinRating ? drive : Container();

          if (widget.search['type'] == "ride")
            drive = _filterCarTypes.contains(ride.vehicle.type)
                ? drive
                : Container();

          return drive;
        }).toList();
        setState(() {
          resultListView = ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            physics: const AlwaysScrollableScrollPhysics(),
            controller: _hideButtonController,
            addAutomaticKeepAlives: true,
            children: results,
          );
          _refreshRequired = false;
        });
      }
      return resultListView;
    }

    Widget createBody() {
      return Scaffold(
        appBar: appBar,
        body: Container(
          color: Theme.of(context).backgroundColor,
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(20, _searchHeight / 5.3, 20, 0),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).accentColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    width: MediaQuery.of(context).size.width,
                    height: _searchHeight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Flexible(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(
                                widget.search['from']['name'].split(',')[0],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22.0,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 30),
                                child: CircleAvatar(
                                  backgroundColor: Colors.white,
                                  radius: 17,
                                  child: Padding(
                                    padding: const EdgeInsets.all(1.0),
                                    child: CircleAvatar(
                                      backgroundColor:
                                          Theme.of(context).accentColor,
                                      radius: 17,
                                      child: Icon(
                                        Icons.arrow_forward,
                                        color: Colors.white,
                                        size: _searchHeight / 3.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                widget.search['to']['name'].split(',')[0],
                                style: TextStyle(
                                    color: Colors.white, fontSize: 22.0),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      widget.search['date'].split('/')[0],
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 20.0),
                                    ),
                                    Text(
                                      widget.search['date'].split('/')[0] ==
                                              '01'
                                          ? 'st'
                                          : widget.search['date']
                                                      .split('/')[0] ==
                                                  '02'
                                              ? 'nd'
                                              : widget.search['date']
                                                          .split('/')[0] ==
                                                      '03'
                                                  ? 'rd'
                                                  : 'th',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Text(
                                    '${getMonthOfYear(widget.search['date'])}, ${getDayOfWeek(widget.search['date'])}',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 15),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _isLoading
                  ? Expanded(
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : rides.length <= 0
                      ? Expanded(
                          child: Center(
                            child: EmptyState(
                              title: AppLocalizations.of(context)
                                  .localisedText['oops'],
                              message: AppLocalizations.of(context)
                                  .localisedText['no_rides_found'],
                            ),
                          ),
                        )
                      : Expanded(child: searchResults()),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: rides.length <= 0 ? null : floatingButton,
      );
    }

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: createBody(),
      ),
    );
  }
}
