import 'demos/action_panel_demo.dart';
import 'demos/app_frame_demo.dart';
import 'demos/cell_editor_demo.dart';
import 'demos/confirm_window_demo.dart';
import 'demos/control_demos.dart';
import 'demos/data_demos.dart';
import 'demos/data_grid_demo.dart';
import 'demos/details_box_demo.dart';
import 'demos/era_editor_host_scope_demo.dart';
import 'demos/foundation_demos.dart';
import 'demos/licences_page_demo.dart';
import 'demos/property_grid_demo.dart';
import 'demos/record_navigator_demo.dart';
import 'demos/shell_demos.dart';
import 'demos/status_bar_demo.dart';
import 'demos/subform_demo.dart';
import 'gallery_demo.dart';

/// Every library widget's demo, sorted by folder and id.
final List<GalleryDemo> galleryDemos = [
  ...foundationDemos,
  ...controlDemos,
  cellEditorDemo,
  eraEditorHostScopeDemo,
  ...dataDemos,
  dataGridDemo,
  propertyGridDemo,
  recordNavigatorDemo,
  subformDemo,
  ...shellDemos,
  actionPanelDemo,
  appFrameDemo,
  confirmWindowDemo,
  detailsBoxDemo,
  licencesPageDemo,
  statusBarDemo,
]..sort((a, b) => a.id.compareTo(b.id));
