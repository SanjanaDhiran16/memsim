
package Memory.RAM is

   type RAM_Type is new Memory_Type with private;

   type RAM_Pointer is access all RAM_Type'Class;

   function Create_RAM(latency : Time_Type := 1) return RAM_Pointer;

   overriding
   procedure Read(mem      : in out RAM_Type;
                  address  : in Address_Type);

   overriding
   procedure Write(mem     : in out RAM_Type;
                   address : in Address_Type);

private

   type RAM_Type is new Memory_Type with record
      latency  : Time_Type := 1;
   end record;

end Memory.RAM;
