package es.icexalumni.icex_atlas;

import androidx.test.rule.ActivityTestRule;
import dev.flutter.plugins.integration_test.FlutterTestRunner;
import org.junit.Rule;
import org.junit.runner.RunWith;

/**
 * Puente entre Android (instrumentación) y los tests de integration_test, para ejecutarlos en
 * Firebase Test Lab. Ver .github/workflows/device-test.yml.
 */
@RunWith(FlutterTestRunner.class)
public class MainActivityTest {
  @Rule
  public ActivityTestRule<MainActivity> rule = new ActivityTestRule<>(MainActivity.class, true, false);
}
