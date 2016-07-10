module mvvm.views.simple;

import dlangui;

Widget createSimpleView()
{
    return parseML(q{
        VerticalLayout {
            EditLine { id: txtTitle; enabled: true }
            TextWidget { id: lblTitle }
            SwitchButton { id: switchIsActive }
            Button { id: btnResetTitle; text: "Reset" }
        }
    });
}
