
package Memory.Learn is

   type Learn_Type is new Memory_Type with private;

   type Learn_Pointer is access all Learn_Type'Class;

   function Create_Learn(mem : access Memory_Type'Class) return Learn_Pointer;

   overriding
   procedure Start(mem : in out Learn_Type);

   overriding
   procedure Commit(mem    : in out Learn_Type;
                    cycles : out Time_Type);

   overriding
   procedure Read(mem      : in out Learn_Type;
                  address  : in Address_Type;
                  size     : in Positive);

   overriding
   procedure Write(mem     : in out Learn_Type;
                   address : in Address_Type;
                   size    : in Positive);

   overriding
   procedure Idle(mem      : in out Learn_Type;
                  cycles   : in Time_Type);

private

   Parameter_Depth : constant := 2;
   Parameter_Count : constant := Address_Type'Size ** Parameter_Depth;

   type Parameter_Array is array(1 .. Parameter_Count) of Float;

   type Learn_Type is new Memory_Type with record
      mem         : access Memory_Type'Class;
      parameters  : Parameter_Array;
      expected    : Address_Type := 0;
      epsilon     : Float := 0.1;
   end record;

   overriding
   procedure Show_Access_Stats(mem : in Learn_Type);

end Memory.Learn;
