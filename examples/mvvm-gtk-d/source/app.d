module app;

import gtk.Main;
import gtk.Widget;

import mvvm.model;
import mvvm.view;

void main(string[] args)
{
	Main.init(args);

	auto viewModel = new AppViewModel;
	auto window = new MyAppWindow(viewModel);
	window.addOnDestroy((Widget _) { Main.quit(); });
	
	window.showAll();

	Main.run();
}
