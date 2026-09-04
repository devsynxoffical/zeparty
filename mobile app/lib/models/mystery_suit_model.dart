class MysterySuitModel {
  final int durationDays;
  final int price;
  final List<String> privileges;
  final String description;

  const MysterySuitModel({
    required this.durationDays,
    required this.price,
    required this.privileges,
    required this.description,
  });

  static const MysterySuitModel standard = MysterySuitModel(
    durationDays: 30,
    price: 800000,
    privileges: [
      'Hide ID',
      'Mystery ID',
      'Invisible Entry',
      'Mystery Entry Frame',
      'Mystery Frame',
      'Mystery Kick',
      'Mystery Voice',
      'Mystery Chat Bubble',
      'Mystery Medal',
      'Anonymous Profile Card',
    ],
    description: 'The Mystery Suit is a special privilege for room, valid for 30 days upon purchase, and can be stacked.\n\n'
        'Opening a duke or higher nobility level will be free to obtain the qualification of mystery suit, Duke for 7 days, King for 15 days, Emperor for 30 days.\n\n'
        'Mystery is only valid in chat rooms. After purchasing, you can freely switch between real identity and Mystery identity in the privacy setting page.\n\n'
        'The privileges of Mystery and Invisible Entry are mutually exclusive, and only one of them can be activated at the same time.\n\n'
        'When entering the room as Mystery identity, a nickname will be randomly assigned.\n\n'
        'When activating the Mystery privilege and speaking on the microphone, the system will automatically change your voice.',
  );
}
