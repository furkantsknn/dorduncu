import 'package:flutter/material.dart';


class GameScreen extends StatelessWidget {


  final String gameName;


  const GameScreen({

    super.key,

    required this.gameName,

  });



  @override
  Widget build(BuildContext context) {


    return Scaffold(


      backgroundColor: Colors.black,



      appBar: AppBar(


        backgroundColor: Colors.black,


        title: Text(

          gameName,

          style: const TextStyle(

            color: Colors.white,

            fontWeight: FontWeight.bold,

          ),

        ),


        iconTheme: const IconThemeData(

          color: Colors.white,

        ),


      ),



      body: Padding(


        padding: const EdgeInsets.all(20),



        child: Column(


          crossAxisAlignment: CrossAxisAlignment.start,



          children: [



            Text(


              "$gameName masaları",


              style: const TextStyle(


                color: Colors.white,

                fontSize:24,

                fontWeight:FontWeight.bold,


              ),


            ),



            const SizedBox(height:20),




            Container(


              width:double.infinity,


              padding:const EdgeInsets.all(20),



              decoration:BoxDecoration(


                color:Colors.white10,


                borderRadius:BorderRadius.circular(15),


              ),



              child:Column(


                crossAxisAlignment:CrossAxisAlignment.start,


                children: [


                  Text(


                    "$gameName masası",


                    style:const TextStyle(


                      color:Colors.white,

                      fontSize:20,

                      fontWeight:FontWeight.bold,


                    ),


                  ),



                  const SizedBox(height:10),



                  const Text(


                    "2 kişi bekliyor",


                    style:TextStyle(


                      color:Colors.white70,


                    ),


                  ),



                ],


              ),


            ),



            const Spacer(),





            SizedBox(


              width:double.infinity,


              height:55,



              child:ElevatedButton(


                onPressed:(){},



                style:ElevatedButton.styleFrom(


                  backgroundColor:Colors.orange,


                ),



                child:const Text(


                  "Masa Oluştur",


                  style:TextStyle(


                    color:Colors.black,

                    fontSize:18,

                    fontWeight:FontWeight.bold,


                  ),


                ),


              ),


            )



          ],


        ),


      ),



    );

  }


}