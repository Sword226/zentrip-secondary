import 'package:flutter_test/flutter_test.dart';
import 'package:zentrip/models/partner_dashboard_model.dart';

void main() {
  test('flight listing payload omits its image while other types retain it',
      () {
    PartnerListing listing({required String type}) => PartnerListing(
          type: type,
          title: 'Listing',
          city: 'Misrata',
          country: 'Libya',
          description: '',
          imageUrl: 'https://example.com/image.jpg',
          price: 100,
          active: true,
        );

    expect(listing(type: 'flight').toJson()['image_url'], isNull);
    expect(
      listing(type: 'hotel').toJson()['image_url'],
      'https://example.com/image.jpg',
    );
  });
}
