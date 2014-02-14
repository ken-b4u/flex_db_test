package
{
	import flash.data.SQLConnection;
	import flash.data.SQLResult;
	import flash.data.SQLSchemaResult;
	import flash.data.SQLStatement;
	import flash.data.SQLTableSchema;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.SQLErrorEvent;
	import flash.events.SQLEvent;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	
	public class DBUtil extends EventDispatcher
	{
		private var _myDB:File;
		private var _isOpen:Boolean = false;
		private var _dbConn:SQLConnection;
		private var _resultArrayCollection:ArrayCollection;
		
		public static const ASYNC_CONNECT_COMPLETE:String = "async_connect_complete";
		public static const ASYNC_SQL_COMPLETE:String = "async_sql_complete";
		public static const SCHEMA_COMPLETE:String = "schema_complete";
		
		public function get myDB():File
		{
			return _myDB;
		} 
		
		public function get isOpen():Boolean
		{
			return _isOpen;
		}
		
		public function get resultArrayCollection():ArrayCollection
		{
			return _resultArrayCollection;
		}
		
		public function DBUtil()
		{
			createLocalDB();
		}
		
		public function createLocalDB():void
		{
			var folder:File = File.applicationStorageDirectory.resolvePath('db');
			folder.createDirectory();
			_myDB = folder.resolvePath('myDBFile.db');
			openLocalDB(_myDB, true);
		}
		
		public function openLocalDB(dbFile:File, isAsync:Boolean):void
		{
			_dbConn = new SQLConnection();
			
			if(isAsync){
				_dbConn.openAsync(dbFile);
				
				_dbConn.addEventListener(SQLEvent.OPEN, sqlOpenHD);
				_dbConn.addEventListener(SQLErrorEvent.ERROR, sqlOpenErrorHD);
				
			}else{
				
				try{
					_dbConn.open(dbFile);
				}catch(e:SQLErrorEvent){
					trace('SQL Error: ' + e.error.message);
					trace('SQL Error Detail: ' + e.error.details);
				}
			}
		}
		
		public function sqlOpenHD(e:SQLEvent):void
		{
			_isOpen = true;
			dispatchEvent(new Event(ASYNC_CONNECT_COMPLETE));
		}
		
		public function sqlOpenErrorHD(e:SQLErrorEvent):void
		{
			_dbConn.removeEventListener(SQLEvent.OPEN, sqlOpenHD);
			_dbConn.removeEventListener(SQLErrorEvent.ERROR, sqlOpenErrorHD);		
			//trace('SQL Error: ' + e.error.message);
			//trace('SQL Error Detail: ' + e.error.details);
			dispatchEvent(e);
		}
		
		public function sqlExcuteErrorHD(e:SQLErrorEvent):void
		{
			var state:SQLStatement = e.target as SQLStatement;
			state.removeEventListener(SQLEvent.RESULT, sqlStatementResultHD);
			state.removeEventListener(SQLErrorEvent.ERROR, sqlExcuteErrorHD);
			//trace('SQL Error: ' + e.error.message);
			//trace('SQL Error Detail: ' + e.error.details);
			dispatchEvent(e);
		}
		
		public function executeSQLState(sqlText:String):void
		{
			if(isOpen == false){
				throw new Error('DB is not connected.');
				return;
			}
			var state:SQLStatement = new SQLStatement();
			state.sqlConnection = _dbConn;
			state.text = sqlText;
			state.addEventListener(SQLEvent.RESULT, sqlStatementResultHD);
			state.addEventListener(SQLErrorEvent.ERROR, sqlExcuteErrorHD);
			state.execute();
		}
		
		private function sqlStatementResultHD(e:SQLEvent):void
		{
			var state:SQLStatement = e.target as SQLStatement;
			state.removeEventListener(SQLEvent.RESULT, sqlStatementResultHD);
			state.removeEventListener(SQLErrorEvent.ERROR, sqlExcuteErrorHD);
			
			var result:SQLResult = state.getResult();
			var temp:Array = result.data is Array ? result.data : [{rows:result.rowsAffected}];
			_resultArrayCollection = new ArrayCollection(temp);
			dispatchEvent(new Event(ASYNC_SQL_COMPLETE));
		}
		
		public function getTableInfo():void
		{
			_dbConn.addEventListener(SQLEvent.SCHEMA, sqlSchemaCompHD);
			_dbConn.addEventListener(SQLErrorEvent.ERROR, sqlSchemaErrorHD);
			_dbConn.loadSchema();
		}
		
		private function sqlSchemaCompHD(e:SQLEvent):void
		{
			_dbConn.removeEventListener(SQLEvent.SCHEMA, sqlSchemaCompHD);
			_dbConn.removeEventListener(SQLErrorEvent.ERROR, sqlSchemaErrorHD);
			
			var result:SQLSchemaResult = _dbConn.getSchemaResult();
			var tables:Array = result.tables;
			var temp:Array = [];
			for each(var tableSchema:SQLTableSchema in tables){
				temp.push({
					database:tableSchema.database, 
					name:tableSchema.name, 
					sql:tableSchema.sql,
					columns:tableSchema.columns.length
				});
			}
			_resultArrayCollection = new ArrayCollection(temp);
			dispatchEvent(new Event(SCHEMA_COMPLETE));
		}
		
		private function sqlSchemaErrorHD(e:SQLErrorEvent):void
		{
			_dbConn.removeEventListener(SQLEvent.SCHEMA, sqlSchemaCompHD);
			_dbConn.removeEventListener(SQLErrorEvent.ERROR, sqlSchemaErrorHD);
			//trace('SQL Error: ' + e.error.message);
			//trace('SQL Error Detail: ' + e.error.details);
			dispatchEvent(e);
		}
	}
}