namespace Test {
	[DBus (name = "org.example.Error")]
	public errordomain CustomError {
		INVALID_ARGUMENT = 1,
		FILE_NOT_FOUND,
		PERMISSION_DENIED = 403
	}
}
