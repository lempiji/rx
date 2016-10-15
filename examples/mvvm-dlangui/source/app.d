module app;

import dlangui;
import rx;

import mvvm.common;
import mvvm.models.simple;
import mvvm.views.simple;

mixin APP_ENTRY_POINT;

/// entry point for dlangui based application
extern (C) int UIAppMain(string[] args)
{
    auto window = Platform.instance.createWindow("Sample Window", null);

    auto view = createSimpleView();
    window.mainWidget = view;
    auto viewModel = new SimpleViewModel;

    // bind command and properties
    bindText(view.childById!EditLine("txtTitle"), viewModel.title);
    bindText(view.childById!TextWidget("lblTitle"), viewModel.title);
    bind(view.childById!SwitchButton("switchIsActive"), viewModel.isActive);
    bind(view.childById!Button("btnResetTitle"), viewModel.clearTitleCommand);

    // show window
    window.show();

    // run message loop
    return Platform.instance.enterMessageLoop();
}
