import 'package:flutter_test/flutter_test.dart';
import 'package:bouncing_ball/main.dart';
import 'package:bouncing_ball/widgets/physics_playground.dart';

void main() {
  testWidgets('Neon Physics Bouncer launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BouncyBallApp());

    // Verify the main Physics Playground and the App title are present
    expect(find.text('PHYSICS BOUNCE'), findsOneWidget);
    expect(find.byType(PhysicsPlayground), findsOneWidget);
  });
}
