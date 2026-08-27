import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

class PdfService {
  static final _currency = NumberFormat.currency(locale: 'fr_FR', symbol: 'Ar', decimalDigits: 0);
  static final _dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

  static Future<void> generateReceipt(Vente vente, String pharmacieNom) async {
    final bytes = await _buildReceipt(vente, pharmacieNom);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes, name: 'ticket_${vente.id}.pdf');
  }

  static Future<void> downloadReceipt(Vente vente, String pharmacieNom) async {
    final bytes = await _buildReceipt(vente, pharmacieNom);
    await Printing.sharePdf(bytes: bytes, filename: 'ticket_${vente.id}.pdf');
  }

  static Future<void> generateReport(
    String pharmacieNom,
    double totalVentes,
    int nbVentes,
    double beneficeBrut,
    List<Medicament> topProduits,
    int Function(String medicamentId) quantiteVendue,
  ) async {
    final bytes = await _buildReport(pharmacieNom, totalVentes, nbVentes, beneficeBrut, topProduits, quantiteVendue);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes, name: 'rapport_pharmacie.pdf');
  }

  static Future<Uint8List> _buildReceipt(Vente vente, String pharmacieNom) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(pharmacieNom, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Lot II K 45, Tananarive', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Tel: 034 12 000 00', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.Divider(),
              pw.Text('Ticket N°: ${vente.id}'),
              pw.Text('Date: ${_dateFormatter.format(vente.date)}'),
              pw.Divider(),
              pw.Table(
                children: [
                  pw.TableRow(
                    children: [
                      pw.Text('Produit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Qté', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  ...vente.items.map((item) => pw.TableRow(
                    children: [
                      pw.Text(item.nom),
                      pw.Text(item.quantite.toString()),
                      pw.Text(_currency.format(item.sousTotal)),
                    ],
                  )),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Sous-total:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(_currency.format(vente.sousTotal)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Remise:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('- ${_currency.format(vente.remiseMontant)}'),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_currency.format(vente.total), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('Merci de votre confiance !')),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  static Future<Uint8List> _buildReport(
    String pharmacieNom,
    double totalVentes,
    int nbVentes,
    double beneficeBrut,
    List<Medicament> topProduits,
    int Function(String medicamentId) quantiteVendue,
  ) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(pharmacieNom, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Rapport de ventes de la pharmacie', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
              pw.Text('Genere le ${_dateFormatter.format(DateTime.now())}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total des ventes :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(_currency.format(totalVentes)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Nombre de ventes :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(nbVentes.toString()),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bénéfice brut :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(_currency.format(beneficeBrut)),
                ],
              ),
              pw.Divider(),
              pw.Text('Top produits vendus', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              if (topProduits.isEmpty)
                pw.Text('Aucune vente enregistrée pour le moment.', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600))
              else
                pw.TableHelper.fromTextArray(
                  headers: const ['Produit', 'Quantité vendue', 'Prix unitaire', 'Total'],
                  data: topProduits.map((m) {
                    final qte = quantiteVendue(m.id);
                    return [
                      m.nomCommercial,
                      qte.toString(),
                      _currency.format(m.prixVente),
                      _currency.format(m.prixVente * qte),
                    ];
                  }).toList(),
                ),
              pw.SizedBox(height: 20),
              pw.Text('PharmaFody\nLot II K 45, Tananarive\nTel: 034 12 000 00', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }
}
