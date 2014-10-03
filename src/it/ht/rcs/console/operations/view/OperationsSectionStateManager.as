package it.ht.rcs.console.operations.view
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.utils.Dictionary;
	
	import it.ht.rcs.console.accounting.controller.UserManager;
	import it.ht.rcs.console.agent.controller.AgentManager;
	import it.ht.rcs.console.agent.model.Agent;
	import it.ht.rcs.console.agent.model.Config;
	import it.ht.rcs.console.events.DataLoadedEvent;
	import it.ht.rcs.console.events.FilterEvent;
	import it.ht.rcs.console.events.SectionEvent;
	import it.ht.rcs.console.evidence.controller.EvidenceManager;
	import it.ht.rcs.console.history.HistoryItem;
	import it.ht.rcs.console.history.HistoryManager;
	import it.ht.rcs.console.monitor.controller.LicenseManager;
	import it.ht.rcs.console.operation.controller.OperationManager;
	import it.ht.rcs.console.operation.model.Operation;
	import it.ht.rcs.console.search.model.SearchItem;
	import it.ht.rcs.console.target.controller.TargetManager;
	import it.ht.rcs.console.target.model.Target;
	
	import locale.R;
	
	import mx.collections.ArrayCollection;
	import mx.collections.ArrayList;
	import mx.collections.ListCollectionView;
	import mx.core.FlexGlobals;
	import mx.managers.CursorManager;
	
	import spark.collections.Sort;
	import spark.collections.SortField;
	import spark.components.TextInput;
	import spark.globalization.SortingCollator;




	public class OperationsSectionStateManager extends EventDispatcher
	{



		[Bindable]
		public var view:ListCollectionView;

		[Bindable]
		public var idents:ArrayCollection;

		[Bindable]
		public var customTypes:ListCollectionView;

		[Bindable]
		public var tableView:ListCollectionView;

		[Bindable]
		public var selectedOperation:Operation;
		[Bindable]
		public var selectedTarget:Target;
		[Bindable]
		public var selectedAgent:Agent;
		[Bindable]
		public var selectedFactory:Agent;
		[Bindable]
		public var selectedConfig:Config;

		private var section:OperationsSection;

		private var customTypeSort:Sort;
		private var tableSort:Sort;
		private var collator:SortingCollator;

		private var previousState:String;

		public static var currInstance:OperationsSectionStateManager;
    
    public static const UPDATE:String="update"

		public function OperationsSectionStateManager(section:OperationsSection)
		{
			this.section=section;
			currInstance=this;

			collator=new SortingCollator();
			collator.ignoreCase=true;
			collator.numericComparison=true;

			customTypeSort=new Sort();
			customTypeSort.compareFunction=customTypeCompareFunction;

			tableSort=new Sort();
			tableSort.compareFunction=customTypeCompareFunction;

			HistoryManager.instance.addEventListener("change", onHistory)
			TargetManager.instance.addEventListener("dataPush", onTargetPush)
			AgentManager.instance.addEventListener("dataPush", onAgentPush)
		}


		private function onTargetPush(e:Event):void
		{
			update()
		}

		private function onAgentPush(e:Event):void
		{
			update()
		}

		private function getItemFromEvent(event:SectionEvent):*
		{
			var item:SearchItem=event ? event.item : null;
			CursorManager.removeBusyCursor()
			if (!item)
				return null;

			switch (item._kind)
			{
				case 'operation':
					return OperationManager.instance.getItem(item._id);
				case 'target':
					return TargetManager.instance.getItem(item._id);
				case 'agent':
				case 'factory':
					return AgentManager.instance.getItem(item._id);
				default:
					return null;
			}
		}

		public function manageItemSelection(i:*, event:SectionEvent=null):void
		{
			var item:*=i || getItemFromEvent(event);
			if (!item)
				return;

			if (CurrentManager)
			{
				CurrentManager.instance.removeEventListener(DataLoadedEvent.DATA_LOADED, onDataLoaded);
				CurrentManager.instance.unlistenRefresh();
			}

			if (item is Operation)
			{
				selectedOperation=item;
				setState('singleOperation');
				UserManager.instance.add_recent(Console.currentSession.user, {id: selectedOperation._id, section: "operations", type: "operation"});
			}

			else if (item is Target && (Console.currentSession.user.is_view() || Console.currentSession.user.is_tech()))
			{
				selectedTarget=item;
				setState('singleTarget');
				UserManager.instance.add_recent(Console.currentSession.user, {id: selectedTarget._id, section: "operations", type: "target"});
			}

			else if (item is Agent && item._kind == 'agent')
			{
				selectedAgent=item;
				setState('singleAgent');
				UserManager.instance.add_recent(Console.currentSession.user, {id: selectedAgent._id, section: "operations", type: "agent"});
			}

			else if (item is Agent && item._kind == 'factory') //&& Console.currentSession.user.is_tech_config()
			{
				selectedFactory=item;
				selectedConfig=null;
				setState('config');
				UserManager.instance.add_recent(Console.currentSession.user, {id: selectedFactory._id, section: "operations", type: "factory"});
			}

			else if (item is Config && Console.currentSession.user.is_tech_config())
			{
				selectedConfig=item;
				setState('config');
			}

			else if (item is Object && item.hasOwnProperty('customType') && item.customType == 'configlist')
			{
				setState('agentConfigList');
			}

			else if (item is Object && item.hasOwnProperty('customType') && item.customType == 'evidence')
			{
				previousState=section.currentState;
				section.currentState='evidence';
				EvidenceManager.instance.refresh();
				saveHistoryItem()
			}

			else if (item is Object && item.hasOwnProperty('customType') && item.customType == 'filesystem')
			{
				previousState=section.currentState;
				section.currentState='filesystem';
				saveHistoryItem()
			}

			else if (item is Object && item.hasOwnProperty('customType') && item.customType == 'info')
			{
				previousState=section.currentState;
				section.currentState='info';
				saveHistoryItem()
			}

			else if (item is Object && item.hasOwnProperty('customType') && item.customType == 'filetransfer')
			{
				previousState=section.currentState;
				section.currentState='filetransfer';
				saveHistoryItem()
			}
			else if (item is Object && item.hasOwnProperty('customType') && item.customType == 'commands') //TODO: DISABLE IN BREADCRUMB
			{
				previousState=section.currentState;
				section.currentState='commands';
				saveHistoryItem()
			}
			else if (item is Object && item.hasOwnProperty('customType') && item.customType == 'ipaddresses')
			{
				previousState=section.currentState;
				section.currentState='ipaddresses';
				saveHistoryItem()
			}

			if (event && event.subsection == 'evidence')
			{
				previousState=section.currentState;
				section.currentState='evidence';
				saveHistoryItem()

				if (event.evidenceTypes)
					EvidenceManager.instance.evidenceFilter.type=event.evidenceTypes;
				else
					delete(EvidenceManager.instance.evidenceFilter.type);




				if (event.info)
				{
					EvidenceManager.instance.evidenceFilter.info=event.info;
				}
				else
				{
					delete(EvidenceManager.instance.evidenceFilter.info);
				}
				if (!isNaN(event.from))
				{
					EvidenceManager.instance.evidenceFilter.date='da';
					EvidenceManager.instance.evidenceFilter.from=event.from;
					EvidenceManager.instance.evidenceFilter.to=event.to;
					if (event.from == -1) //trick
					{
						EvidenceManager.instance.evidenceFilter.date='dr';
						EvidenceManager.instance.evidenceFilter.from="24h";
					}
				}
				else
				{
					delete(EvidenceManager.instance.evidenceFilter.date);
					delete(EvidenceManager.instance.evidenceFilter.from);
					delete(EvidenceManager.instance.evidenceFilter.to);
				}

				if (event.evidenceIds)
				{
					EvidenceManager.instance.evidenceFilter.date='dr';
					EvidenceManager.instance.evidenceFilter.from=0; //0
					EvidenceManager.instance.evidenceFilter.to=0; //0
					EvidenceManager.instance.evidenceFilter._id=event.evidenceIds;
				}
				else
					delete(EvidenceManager.instance.evidenceFilter._id);

				var f:Object=EvidenceManager.instance.evidenceFilter;
				FlexGlobals.topLevelApplication.dispatchEvent(new FilterEvent(FilterEvent.REBUILD));
				section.evidenceView.refreshData();
			}
		}

		private function clearVars():void
		{
			selectedOperation=null;
			selectedTarget=null;
			selectedAgent=null;
			selectedFactory=null;
			selectedConfig=null;
		}

		private function onHistory(e:Event):void
		{
			trace("ON HISTORY")
			if (HistoryManager.instance.currentItem.section == "Operations")
			{
				var hi:HistoryItem=HistoryManager.instance.currentItem;
				selectedOperation=HistoryManager.instance.currentItem.operation;
				selectedTarget=HistoryManager.instance.currentItem.target;
				selectedAgent=HistoryManager.instance.currentItem.agent;
				selectedFactory=HistoryManager.instance.currentItem.factory;
				selectedConfig=HistoryManager.instance.currentItem.config;
				if (!HistoryManager.instance.currentItem.state)
					HistoryManager.instance.currentItem.state="allOperations"
				if (HistoryManager.instance.currentItem.state == "commands")
					section.currentState='commands';
				else if (HistoryManager.instance.currentItem.state == "info")
					section.currentState='info';
				else if (HistoryManager.instance.currentItem.state == "ipaddresses")
					section.currentState='ipaddresses';
				else if (HistoryManager.instance.currentItem.state == "filesystem")
					section.currentState='filesystem';
				else if (HistoryManager.instance.currentItem.state == "filetransfer")
					section.currentState='filetransfer';
				else if (HistoryManager.instance.currentItem.state == "evidence")
					section.currentState='evidence';
				else
					setState(HistoryManager.instance.currentItem.state, false)

					//TODO !!! evidence, commands, etc....
			}
		}

		private var currentState:String;

		public function setState(state:String, bookmark:Boolean=true):void
		{
			if (!state)
				return;

			previousState=currentState;
			currentState=state;
			if (CurrentManager)
			{
				CurrentManager.instance.removeEventListener(DataLoadedEvent.DATA_LOADED, onDataLoaded);
				CurrentManager.instance.unlistenRefresh();
			}
			switch (currentState)
			{
				case 'allOperations':
					clearVars();
					section.currentState='allOperations';
					CurrentManager=OperationManager;
					if (searchField)
						searchField.text='';
					currentFilter=searchFilterFunction;
					update();
					break;
				case 'allTargets':
					clearVars();
					section.currentState='allTargets';
					CurrentManager=TargetManager;
					if (searchField)
						searchField.text='';
					currentFilter=searchFilterFunction;
					update();
					break;
				case 'allAgents':
					clearVars();
					section.currentState='allAgents';
					CurrentManager=AgentManager;
					if (searchField)
						searchField.text='';
					currentFilter=searchFilterFunction;
					prepareAgentsDictionary();
					update();
					break;

				case 'singleOperation':
					selectedTarget=null;
					selectedAgent=null;
					selectedFactory=null;
					selectedConfig=null;
					section.currentState='singleOperation';
					CurrentManager=TargetManager;
					currentFilter=singleOperationFilterFunction;
					update();
					break;
				case 'singleTarget':
					selectedAgent=null;
					selectedFactory=null;
					selectedConfig=null;
					selectedOperation=OperationManager.instance.getItem(selectedTarget.path[0]);
					section.currentState='singleTarget';
					CurrentManager=AgentManager;
					currentFilter=singleTargetFilterFunction;
					prepareAgentsDictionary();
					update();
					break;
				case 'singleAgent':
					selectedFactory=null;
					selectedConfig=null;
					selectedOperation=OperationManager.instance.getItem(selectedAgent.path[0]);
					selectedTarget=TargetManager.instance.getItem(selectedAgent.path[1]);
					section.currentState='singleAgent';
					CurrentManager=null;
					currentFilter=searchFilterFunction;
					update();
					break;

				case 'agentConfigList':
					selectedConfig=null;
					section.currentState='agentConfigList';
					break;

				case 'config':
					var agent:Agent;
					if (selectedFactory)
					{
						agent=selectedFactory;
						selectedAgent=null;
					}
					else
					{
						agent=selectedAgent;
						selectedFactory=null;
					}

					selectedOperation=OperationManager.instance.getItem(agent.path[0]);
					if (agent.path.length > 1)
						selectedTarget=TargetManager.instance.getItem(agent.path[1]);
					if (section.configView)
						section.configView.currentState='blank';
					section.currentState='config';
					section.configView.getConfig();
					CurrentManager=null;
					currentFilter=searchFilterFunction;
					update();
					break;

				default:
					break;
			}

			if (bookmark)
			{
				saveHistoryItem()
			}

			if (CurrentManager)
			{
				CurrentManager.instance.addEventListener(DataLoadedEvent.DATA_LOADED, onDataLoaded);
				CurrentManager.instance.listenRefresh();
			}
		}

		private function onDataLoaded(e:DataLoadedEvent):void
		{
			setState(section.currentState);
		}

		private function update():void
		{
			removeCustomTypes(view);
			view=getView();
			customTypes=getCustomTypes();
			removeCustomTypes(view);
			addCustomTypes(view);
			if (view)
				view.refresh();

			if (CurrentManager != null)
			{
				tableView=CurrentManager.instance.getView(tableSort, tableFilterFunction);
				tableView.refresh();
			}

			if (currentState == 'singleTarget')
			{
				var i:int;
        var identDictionary:Dictionary=new Dictionary()
				for (i=0; i < view.length; i++)
				{
					if(!identDictionary[view.getItemAt(i).ident])
            identDictionary[view.getItemAt(i).ident]=new ArrayCollection()
          identDictionary[view.getItemAt(i).ident].addItem(view.getItemAt(i))
				}
        idents=new ArrayCollection
        for each (var ident:ArrayCollection in identDictionary)
        {
          idents.addItem(ident);
        }
			}
      dispatchEvent(new Event(UPDATE));
		}

		private function tableFilterFunction(item:Object):Boolean
		{
			if (item.hasOwnProperty('customType'))
				return false;
			else if (currentFilter != null)
				return currentFilter(item);
			else
				return true;
		}

		private function removeCustomTypes(list:ListCollectionView):void
		{
			if (list != null && list.length > 0)
				for (var i:int=0; i < list.length; i++)
					if (list.getItemAt(i).hasOwnProperty('customType'))
					{
						list.removeItemAt(i);
						i--;
					}
		}

		private function getCustomTypes():ListCollectionView
		{
			customTypes=new ListCollectionView()
			customTypes.list=new ArrayList();
      
      
      if((currentState == 'singleTarget' || currentState == 'singleAgent') && (Console.currentSession.user.is_view()))
      {
        customTypes.addItem({name: R.get('EVIDENCE'), customType: 'evidence'})
        if (Console.currentSession.user.is_view_filesystem())
        {
        customTypes.addItem({name: R.get('FILE_SYSTEM'), customType: 'filesystem'})}
      }
      if (currentState == 'singleAgent')
      {
        customTypes.addItem({name: R.get('INFO'), customType: 'info'});
        if (LicenseManager.instance.modify)
        {
          customTypes.addItem({name: R.get('COMMANDS'), customType: 'commands'});
        }
        customTypes.addItem({name: R.get('SYNC_HISTORY'), customType: 'ipaddresses'});
        if (Console.currentSession.user.is_tech())
        {
          customTypes.addItem({name: R.get('CONFIG'), customType: 'configlist'});
          customTypes.addItem({name: R.get('FILE_TRANSFER'), customType: 'filetransfer'});
          
        }
      }
			return customTypes;
		}

		private function addCustomTypes(list:ListCollectionView):void
		{
			if (list == null)
				return;
			//if ((currentState == 'singleTarget' || currentState == 'singleAgent') && (Console.currentSession.user.is_view()))
			if ((currentState == 'singleAgent') && (Console.currentSession.user.is_view()))
			{
				list.addItemAt({name: R.get('EVIDENCE'), customType: 'evidence', order: 0}, 0);
				if (Console.currentSession.user.is_view_filesystem())
				{
					list.addItemAt({name: R.get('FILE_SYSTEM'), customType: 'filesystem', order: 1}, 0);
				}
			}
			if (currentState == 'singleAgent')
			{
        if (Console.currentSession.user.is_tech())
        {
          list.addItemAt({name: R.get('CONFIG'), customType: 'configlist', order: 2}, 0);
        }
				list.addItemAt({name: R.get('INFO'), customType: 'info', order: 3}, 0);
				if (LicenseManager.instance.modify)
				{
					list.addItemAt({name: R.get('COMMANDS'), customType: 'commands', order: 4}, 0);
				}
				list.addItemAt({name: R.get('SYNC_HISTORY'), customType: 'ipaddresses', order: 5}, 0);
				if (Console.currentSession.user.is_tech())
				{
					list.addItemAt({name: R.get('FILE_TRANSFER'), customType: 'filetransfer', order: 6}, 0);

				}
			}
		}

		private function getView():ListCollectionView
		{
			var lcv:ListCollectionView;
			if (currentState == 'singleOperation')
			{

				lcv=new ListCollectionView()
				var targets:ListCollectionView=TargetManager.instance.getView(customTypeSort, currentFilter);
				var factories:ListCollectionView=AgentManager.instance.getFactoriesForOperation(selectedOperation._id);
				var items:Array=new Array()
				var i:int=0;
				for (i=0; i < targets.length; i++)
				{
					items.push(targets.getItemAt(i))
				}
				for (i=0; i < factories.length; i++)
				{
					items.push(factories.getItemAt(i))
				}
				lcv.list=new ArrayList(items);
				lcv.filterFunction=currentFilter;
				lcv.refresh();

			}

			else if (CurrentManager != null)
			{
				lcv=CurrentManager.instance.getView(customTypeSort, currentFilter);
			}


			else if (currentState == 'singleAgent')
			{
				lcv=new ListCollectionView(new ArrayList());
				lcv.sort=customTypeSort;
				lcv.filterFunction=currentFilter;
			}


			return lcv;
		}

		private var CurrentManager:Class;
		private var currentSort:Sort;
		private var currentFilter:Function;

		// First, custom types, custom order
		// Second, factories, alphabetical oder
		// Third, agents, alphabetical order
		private function customTypeCompareFunction(a:Object, b:Object, fields:Array=null):int
		{
			if (!a && !b)
				return 0;
			if (a && !b)
				return -1;
			if (!a && b)
				return 1;

			var aIsCustom:Boolean=a.hasOwnProperty('customType');
			var bIsCustom:Boolean=b.hasOwnProperty('customType');

			if (aIsCustom && bIsCustom)
			{
				var distance:int=a.order - b.order;
				return distance / Math.abs(distance);
			}
			if (aIsCustom)
				return -1;
			if (bIsCustom)
				return 1;

			var aIsAgent:Boolean=a is Agent;
			var bIsAgent:Boolean=b is Agent;
			//agent
			if (aIsAgent && bIsAgent)
			{

				var aIsFactory:Boolean=a._kind == 'factory';
				var bIsFactory:Boolean=b._kind == 'factory';

				if (aIsFactory && bIsFactory)
					return collator.compare(a.name, b.name);

				if (!aIsFactory && !bIsFactory)
				{
					if (a.ident == b.ident)
						return collator.compare(a.name, b.name);
					return collator.compare(getFactory(a.ident).name, getFactory(b.ident).name);
				}

				if (aIsFactory && !bIsFactory)
				{
					if (a.ident == b.ident)
						return -1;
					return collator.compare(a.name, getFactory(b.ident).name);
				}

				if (!aIsFactory && bIsFactory)
				{
					if (a.ident == b.ident)
						return 1;
					return collator.compare(getFactory(a.ident).name, b.name);
				}

			}
			//end agent
			return collator.compare(a.name, b.name);

		}

		private var agentsDict:Dictionary;

		private function prepareAgentsDictionary():void
		{
			agentsDict=new Dictionary(true);
			for each (var agent:Object in AgentManager.instance.getView())
				if (agent is Agent && agent._kind == 'factory')
					agentsDict[agent.ident]=agent;
		}

		private function getFactory(ident:String):Object
		{
			var f:Agent=agentsDict[ident];
			return f ? f : {name: ''};
		}

		// This reference is injected by the action bars, when they are displayed
		public var searchField:TextInput;

		private function searchFilterFunction(item:Object):Boolean
		{
			/*   if(item is Agent)// show factory to tech users only
				 {
					 if (!(Console.currentSession.user.is_tech_factories()) && item._kind == 'factory')
						 return false;
				 }*/

			if (!searchField || searchField.text == '')
				return true;

			var result:Boolean=false;
			if (item && item.hasOwnProperty('name') && item.name)
				result=result || String(item.name.toLowerCase()).indexOf(searchField.text.toLowerCase()) >= 0;

			if (item && item.hasOwnProperty('instance') && item.instance)
				result=result || String(item.instance.toLowerCase()).indexOf(searchField.text.toLowerCase()) >= 0;

			if (item && item.hasOwnProperty('desc') && item.desc)
				result=result || String(item.desc.toLowerCase()).indexOf(searchField.text.toLowerCase()) >= 0;

			if (item && item.hasOwnProperty('ident') && item.ident)
				result=result || String(item.desc.toLowerCase()).indexOf(searchField.text.toLowerCase()) >= 0;
			//

			return result;
		}

		private function singleOperationFilterFunction(item:Object):Boolean
		{
			if (selectedOperation && ((item is Target && item.path[0] == selectedOperation._id) || (item is Agent && item._kind == 'factory' && item.path.length == 1 && item.path[0] == selectedOperation._id)))
			{
				return searchFilterFunction(item);
			}
			return false;
		}


		private function saveHistoryItem():void
		{
			var currentItem:HistoryItem=HistoryManager.instance.currentItem
			//if is different add a new item in HM
			if (HistoryManager.instance.currentItem.section == "Operations" && (HistoryManager.instance.currentItem.state == null || HistoryManager.instance.currentItem.state != previousState))
			{
				HistoryManager.instance.currentItem.state=section.currentState;
				HistoryManager.instance.currentItem.operation=selectedOperation
				HistoryManager.instance.currentItem.target=selectedTarget;
				HistoryManager.instance.currentItem.agent=selectedAgent;
				HistoryManager.instance.currentItem.factory=selectedFactory;
				HistoryManager.instance.currentItem.config=selectedConfig;
			}
			else if (HistoryManager.instance.currentItem.section == "Operations" && (HistoryManager.instance.currentItem.state != null || HistoryManager.instance.currentItem.state == previousState))
			{
				var item:HistoryItem=new HistoryItem;
				item.section="Operations";
				item.subSection=0;
				item.state=section.currentState;
				item.operation=selectedOperation
				item.target=selectedTarget;
				item.agent=selectedAgent;
				item.factory=selectedFactory;
				item.config=selectedConfig;
				HistoryManager.instance.addItem(item)
			}
			HistoryManager.instance.dumpHistory()
		}



		private function singleTargetFilterFunction(item:Object):Boolean
		{
			if (item.hasOwnProperty('customType'))
				return true; //return searchFilterFunction(item);
			if (selectedTarget && item.path && item.path.length > 1)
			{
				if (selectedTarget && item is Agent && item.path[1] == selectedTarget._id)
					/*  if (!(Console.currentSession.user.is_tech_factories()) && item._kind == 'factory')
							return false;
						else*/
					return searchFilterFunction(item);
				else
					return false;
			}
			return false;
		}

	}

}
